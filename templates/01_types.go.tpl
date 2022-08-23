{{$table := .Table}}
{{$tAlias := .Aliases.Table $table.Name -}}

// {{$tAlias.UpSingular}}Slice is an Alias for a slice of pointers to {{$tAlias.UpSingular}}.
// This should almost always be used instead of []{{$tAlias.UpSingular}}.
type {{$tAlias.UpSingular}}Slice []*{{$tAlias.UpSingular}}

// {{$tAlias.UpSingular}} is an object representing the database table.
type {{$tAlias.UpSingular}} struct {
	{{- range $column := .Table.Columns -}}
	{{- $colAlias := $tAlias.Column $column.Name -}}
	{{- $orig_col_name := $column.Name -}}
	{{- range $column.Comment | splitLines -}} // {{ . }}
	{{end -}}
	{{if ignore $table.Name $orig_col_name $.TagIgnore -}}
	{{$colAlias}} {{$column.Type}} `{{generateIgnoreTags $.Tags}}db:"{{$column.Name}}" json:"-" toml:"-" yaml:"-"`
	{{else if eq $.StructTagCasing "title" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}db:"{{$column.Name}}" json:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | titleCase}}" yaml:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else if eq $.StructTagCasing "camel" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}db:"{{$column.Name}}" json:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | camelCase}}" yaml:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else if eq $.StructTagCasing "tAlias" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $colAlias}}db:"{{$column.Name}}" json:"{{$colAlias}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$colAlias}}" yaml:"{{$colAlias}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}db:"{{$column.Name}}" json:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name}}" yaml:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}"`
	{{end -}}
	{{end -}}
	{{- if or .Table.IsJoinTable .Table.IsView -}}
	{{- else}}
	R {{$tAlias.DownSingular}}R `{{generateTags $.Tags "-"}}db:"{{"-"}}" json:"{{"-"}}" toml:"{{"-"}}" yaml:"{{"-"}}"`
	{{end -}}
}

{{if or .Table.IsJoinTable .Table.IsView -}}{{- else -}}
// Optional{{$tAlias.UpSingular}} is used for insert/upsert operations
// Every field has to be explicitly set to know which columns to insert
type Optional{{$tAlias.UpSingular}} struct {
	{{- range $column := .Table.Columns -}}
	{{- $colAlias := $tAlias.Column $column.Name -}}
	{{$colAlias}} omit.Val[{{$column.Type}}] `db:"{{$column.Name}}"`
	{{end -}}
}

// {{$tAlias.DownSingular}}R is where relationships are stored.
type {{$tAlias.DownSingular}}R struct {
	{{range .Table.FKeys -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $tAlias.Relationship .Name -}}
	{{$relAlias.Foreign}} *{{$ftable.UpSingular}} `{{generateTags $.Tags $relAlias.Foreign}}db:"{{$relAlias.Foreign}}" json:"{{$relAlias.Foreign}}" toml:"{{$relAlias.Foreign}}" yaml:"{{$relAlias.Foreign}}"`
	{{end -}}

	{{range .Table.ToOneRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	{{$relAlias.Local}} *{{$ftable.UpSingular}} `{{generateTags $.Tags $relAlias.Local}}db:"{{$relAlias.Local}}" json:"{{$relAlias.Local}}" toml:"{{$relAlias.Local}}" yaml:"{{$relAlias.Local}}"`
	{{end -}}

	{{range .Table.ToManyRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	{{$relAlias.Local}} {{printf "%sSlice" $ftable.UpSingular}} `{{generateTags $.Tags $relAlias.Local}}db:"{{$relAlias.Local}}" json:"{{$relAlias.Local}}" toml:"{{$relAlias.Local}}" yaml:"{{$relAlias.Local}}"`
	{{end -}}{{/* range tomany */}}
}
{{- end}}

type {{$tAlias.DownSingular}}ColumnNames struct {
	{{range $column := $table.Columns -}}
	{{- $colAlias := $tAlias.Column $column.Name -}}
	{{$colAlias}} string
  {{end -}}
}
