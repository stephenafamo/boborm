package main

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/volatiletech/sqlboiler/v4/boilingcore"
	"github.com/volatiletech/sqlboiler/v4/drivers"
	"github.com/volatiletech/sqlboiler/v4/importers"
)

//go:embed templates
var templates embed.FS

const boilingSeedVersion = "0.1.0"

var (
	flagConfigFile string
	cmdState       *boilingcore.State
	cmdConfig      *boilingcore.Config
	dialect        string
)

func initConfig() {
	if len(flagConfigFile) != 0 {
		viper.SetConfigFile(flagConfigFile)
		if err := viper.ReadInConfig(); err != nil {
			fmt.Println("Can't read config:", err)
			os.Exit(1)
		}
		return
	}

	var err error
	viper.SetConfigName("sqlboiler")

	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "sqlboiler"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/sqlboiler"))
	}

	for _, p := range configPaths {
		viper.AddConfigPath(p)
	}

	// Ignore errors here, fallback to other validation methods.
	// Users can use environment variables if a config is not found.
	_ = viper.ReadInConfig()
}

func main() {
	// Too much happens between here and cobra's argument handling, for
	// something so simple just do it immediately.
	for _, arg := range os.Args {
		if arg == "--version" {
			fmt.Println("BoilingSeed v" + boilingSeedVersion)
			return
		}
	}

	// Set up the cobra root command
	rootCmd := &cobra.Command{
		Use:   "boilingseed [flags] <driver>",
		Short: "BoilingSeed generates seeder for your SQLBoiler models.",
		Long: "BoilingSeed generates seeder for your SQLBoiler models.\n" +
			`Complete documentation is available at http://github.com/stephenafamo/boilingseed`,
		Example:       `boilingseed psql`,
		PreRunE:       preRun,
		RunE:          run,
		PostRunE:      postRun,
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	cobra.OnInitialize(initConfig)

	// Set up the cobra root command flags
	rootCmd.PersistentFlags().StringVarP(&flagConfigFile, "config", "c", "", "Filename of config file to override default lookup")
	rootCmd.PersistentFlags().String("sqlboiler-models", "", "The package of your generated models. Needed to import them properly in the seeder files.")
	rootCmd.PersistentFlags().StringP("output", "o", "models", "The name of the folder to output to")
	rootCmd.PersistentFlags().StringP("pkgname", "p", "models", "The name you wish to assign to your generated package")
	rootCmd.PersistentFlags().BoolP("debug", "d", false, "Debug mode prints stack traces on error")
	rootCmd.PersistentFlags().BoolP("no-context", "", false, "Disable context.Context usage in the generated code")
	rootCmd.PersistentFlags().BoolP("no-tests", "", false, "Disable generated go test files")
	// Use hooks instead of // AfterXXXAdded
	// rootCmd.PersistentFlags().BoolP("no-hooks", "", false, "Disable hooks feature for your models")
	rootCmd.PersistentFlags().BoolP("version", "", false, "Print the version")
	rootCmd.PersistentFlags().BoolP("wipe", "", false, "Delete the output folder (rm -rf) before generation to ensure sanity")

	// hide flags not recommended for use
	rootCmd.PersistentFlags().MarkHidden("no-tests")

	viper.BindPFlags(rootCmd.PersistentFlags())
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))
	viper.AutomaticEnv()

	if err := rootCmd.Execute(); err != nil {
		if e, ok := err.(commandFailure); ok {
			fmt.Printf("Error: %v\n\n", string(e))
			rootCmd.Help()
		} else if !viper.GetBool("debug") {
			fmt.Printf("Error: %v\n", err)
		} else {
			fmt.Printf("Error: %+v\n", err)
		}

		os.Exit(1)
	}
}

type commandFailure string

func (c commandFailure) Error() string {
	return string(c)
}

func preRun(cmd *cobra.Command, args []string) error {
	var err error

	if len(args) == 0 {
		return commandFailure("must provide a driver name")
	}

	driverName, driverPath, err := drivers.RegisterBinaryFromCmdArg(args[0])
	if err != nil {
		return fmt.Errorf("could not register driver: %w", err)
	}
	dialect = driverName

	cmdConfig = &boilingcore.Config{
		DriverName: driverName,
		OutFolder:  viper.GetString("output"),
		PkgName:    viper.GetString("pkgname"),
		Debug:      viper.GetBool("debug"),
		NoContext:  viper.GetBool("no-context"),
		NoTests:    viper.GetBool("no-tests"),
		Wipe:       viper.GetBool("wipe"),
		Version:    "boilingseed-" + boilingSeedVersion,

		// Things we specifically override
		DefaultTemplates:    templates,
		CustomTemplateFuncs: customFuncs,
		NoDriverTemplates:   true,
	}

	if cmdConfig.Debug {
		fmt.Fprintln(os.Stderr, "using driver:", driverPath)
	}

	// Configure the driver
	cmdConfig.DriverConfig = map[string]interface{}{
		"whitelist": viper.GetStringSlice(driverName + ".whitelist"),
		"blacklist": viper.GetStringSlice(driverName + ".blacklist"),
	}

	keys := allKeys(driverName)
	for _, key := range keys {
		if key != "blacklist" && key != "whitelist" {
			prefixedKey := fmt.Sprintf("%s.%s", driverName, key)
			cmdConfig.DriverConfig[key] = viper.Get(prefixedKey)
		}
	}

	cmdConfig.Imports = configureImports()

	cmdState, err = boilingcore.New(cmdConfig)
	return err
}

func run(cmd *cobra.Command, args []string) error {
	return cmdState.Run()
}

func postRun(cmd *cobra.Command, args []string) error {
	return cmdState.Cleanup()
}

func allKeys(prefix string) []string {
	keys := make(map[string]bool)

	prefix += "."

	for _, e := range os.Environ() {
		splits := strings.SplitN(e, "=", 2)
		key := strings.ReplaceAll(strings.ToLower(splits[0]), "_", ".")

		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	for _, key := range viper.AllKeys() {
		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	keySlice := make([]string, 0, len(keys))
	for k := range keys {
		keySlice = append(keySlice, k)
	}
	return keySlice
}

func configureImports() importers.Collection {
	imports := importers.NewDefaultImports()

	imports.All.Standard = []string{`"context"`, `"fmt"`, `"errors"`, `"database/sql"`}
	imports.All.ThirdParty = []string{
		`"github.com/aarondl/opt/omit"`,
		`"github.com/stephenafamo/scan"`,
		`"github.com/stephenafamo/bob"`,
		`"github.com/stephenafamo/bob/orm"`,
		fmt.Sprintf(`"github.com/stephenafamo/bob/dialect/%s"`, dialect),
		fmt.Sprintf(`"github.com/stephenafamo/bob/dialect/%s/model"`, dialect),
	}
	imports.Singleton["boborm_main"] = importers.Set{
		Standard: nil,
		ThirdParty: []string{
			fmt.Sprintf(`"github.com/stephenafamo/bob/dialect/%s"`, dialect),
			fmt.Sprintf(`"github.com/stephenafamo/bob/dialect/%s/model"`, dialect),
		},
	}

	return imports
}

var customFuncs = template.FuncMap{
	"quoteAndJoin": func(s1, s2 string) string {
		if s1 == "" && s2 == "" {
			return ""
		}

		if s1 == "" {
			return fmt.Sprintf("%q", s2)
		}

		if s2 == "" {
			return fmt.Sprintf("%q", s1)
		}

		return fmt.Sprintf("%q, %q", s1, s2)
	},
}
