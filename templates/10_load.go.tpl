{{$table := .Table}}
{{$tAlias := .Aliases.Table $table.Name -}}

func (o *{{$tAlias.UpSingular}}) EagerLoad(name string, retrieved any) error {
	if o == nil {
		return nil
	}

	switch name {
	{{range $table.FKeys -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $tAlias.Relationship .Name -}}
	case "{{$relAlias.Foreign}}":
		if rel, ok := retrieved.(*{{$ftable.UpSingular}}); ok {
			o.R.{{$relAlias.Foreign}} = rel
			return nil
		}
		return fmt.Errorf("{{$tAlias.DownSingular}} cannot load %T as %q", retrieved, name)

	{{end -}}

	{{range $table.ToOneRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	case "{{$relAlias.Local}}":
		if rel, ok := retrieved.(*{{$ftable.UpSingular}}); ok {
			o.R.{{$relAlias.Local}} = rel
			return nil
		}
		return fmt.Errorf("{{$tAlias.DownSingular}} cannot load %T as %q", retrieved, name)

	{{end -}}

	{{range $table.ToManyRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	case "{{$relAlias.Local}}":
		if rel, ok := retrieved.({{$ftable.UpSingular}}Slice); ok {
			o.R.{{$relAlias.Local}} = rel
			return nil
		}
		return fmt.Errorf("{{$tAlias.DownSingular}} cannot load %T as %q", retrieved, name)

	{{end -}}
	default:
		return fmt.Errorf("{{$tAlias.DownSingular}} has no relationship %q", name)
	}
}

{{range $table.FKeys -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $tAlias.Relationship .Name -}}
{{- $col := index $tAlias.Columns .Column -}}
{{- $fcol := index $ftable.Columns .ForeignColumn -}}
func Preload{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(opts ...model.EagerLoadOption) model.EagerLoader {
	return model.Preload[*{{$ftable.UpSingular}}, {{$ftable.UpSingular}}Slice](orm.Relationship{
			Name: "{{$relAlias.Foreign}}",
			LocalTable:   TableNames.{{$tAlias.UpPlural}},
			ForeignTable: TableNames.{{$ftable.UpPlural}},
			ColumnPairs:  map[string]string{
				ColumnNames.{{$tAlias.UpPlural}}.{{$col}}: ColumnNames.{{$ftable.UpPlural}}.{{$fcol}},
			},
		}, {{$ftable.UpPlural}}Table.Columns(), opts...)
}

func ThenLoad{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(queryMods ...bob.Mod[*psql.SelectQuery]) model.Loader {
	return model.Loader(func(ctx context.Context, exec scan.Queryer, retrieved any) error {
		loader, isLoader := retrieved.(interface{
			Load{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(context.Context, scan.Queryer, ...bob.Mod[*psql.SelectQuery]) error
		})
		if !isLoader {
			return fmt.Errorf("object %T cannot load {{$tAlias.UpSingular}}{{$relAlias.Foreign}}", retrieved)
		}

		return loader.Load{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(ctx, exec, queryMods...)
	})
}

func (o *{{$tAlias.UpSingular}}) Load{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.EQ(psql.Arg(o.{{$col}}))))

	{{$ftable.DownSingular}}, err := q.One(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	o.R.{{$relAlias.Foreign}} = {{$ftable.DownSingular}}
	return nil
}

func (os {{$tAlias.UpSingular}}Slice) Load{{$tAlias.UpSingular}}{{$relAlias.Foreign}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	cols := make([]any, len(os))
	for i, o := range os {
		cols[i] = psql.Arg(o.{{$col}})
	}

	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.In(cols...)))

	{{$ftable.DownPlural}}, err := q.All(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	for _, rel := range {{$ftable.DownPlural}} {
		for _, o := range os {
			if rel.{{$fcol}} == o.{{$col}} {
				o.R.{{$relAlias.Foreign}} =  rel
			}
		}
	}

	return nil
}

{{end -}}

{{range $table.ToOneRelationships -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $ftable.Relationship .Name -}}
{{- $col := index $tAlias.Columns .Column -}}
{{- $fcol := index $ftable.Columns .ForeignColumn -}}
func Preload{{$tAlias.UpSingular}}{{$relAlias.Local}}(opts ...model.EagerLoadOption) model.EagerLoader {
	return model.Preload[*{{$ftable.UpSingular}}, {{$ftable.UpSingular}}Slice](orm.Relationship{
			Name: "{{$relAlias.Foreign}}",
			LocalTable:   TableNames.{{$tAlias.UpPlural}},
			ForeignTable: TableNames.{{$ftable.UpPlural}},
			ColumnPairs:  map[string]string{
				ColumnNames.{{$tAlias.UpPlural}}.{{$col}}: ColumnNames.{{$ftable.UpPlural}}.{{$fcol}},
			},
		}, {{$ftable.UpPlural}}Table.Columns(), opts...)
}

func ThenLoad{{$tAlias.UpSingular}}{{$relAlias.Local}}(queryMods ...bob.Mod[*psql.SelectQuery]) model.Loader {
	return model.Loader(func(ctx context.Context, exec scan.Queryer, retrieved any) error {
		loader, isLoader := retrieved.(interface{
			Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(context.Context, scan.Queryer, ...bob.Mod[*psql.SelectQuery]) error
		})
		if !isLoader {
			return fmt.Errorf("object %T cannot load {{$tAlias.UpSingular}}{{$relAlias.Local}}", retrieved)
		}

		return loader.Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx, exec, queryMods...)
	})
}

func (o *{{$tAlias.UpSingular}}) Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.EQ(psql.Arg(o.{{$col}}))))

	{{$ftable.DownSingular}}, err := q.One(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	o.R.{{$relAlias.Local}} = {{$ftable.DownSingular}}
	return nil
}

func (os {{$tAlias.UpSingular}}Slice) Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	cols := make([]any, len(os))
	for i, o := range os {
		cols[i] = psql.Arg(o.{{$col}})
	}

	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.In(cols...)))

	{{$ftable.DownPlural}}, err := q.All(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	for _, rel := range {{$ftable.DownPlural}} {
		for _, o := range os {
			if rel.{{$fcol}} == o.{{$col}} {
				o.R.{{$relAlias.Local}} =  rel
			}
		}
	}

	return nil
}

{{end -}}


{{range $table.ToManyRelationships -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
{{- $col := index $tAlias.Columns .Column -}}
{{- $fcol := index $ftable.Columns .ForeignColumn -}}
func ThenLoad{{$tAlias.UpSingular}}{{$relAlias.Local}}(queryMods ...bob.Mod[*psql.SelectQuery]) model.Loader {
	return model.Loader(func(ctx context.Context, exec scan.Queryer, retrieved any) error {
		loader, isLoader := retrieved.(interface{
			Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(context.Context, scan.Queryer, ...bob.Mod[*psql.SelectQuery]) error
		})
		if !isLoader {
			return fmt.Errorf("object %T cannot load {{$tAlias.UpSingular}}{{$relAlias.Local}}", retrieved)
		}

		return loader.Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx, exec, queryMods...)
	})
}


func (o *{{$tAlias.UpSingular}}) Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.EQ(psql.Arg(o.{{$col}}))))

	{{$ftable.DownPlural}}, err := q.All(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	o.R.{{$relAlias.Local}} = {{$ftable.DownPlural}}
	return nil
}

func (os {{$tAlias.UpSingular}}Slice) Load{{$tAlias.UpSingular}}{{$relAlias.Local}}(ctx context.Context, exec scan.Queryer, mods ...bob.Mod[*psql.SelectQuery]) error {
	cols := make([]any, len(os))
	for i, o := range os {
		cols[i] = psql.Arg(o.{{$col}})
	}

	q := {{$ftable.UpPlural}}(mods...)
	q.Apply(psql.SelectQM.Where({{$ftable.UpSingular}}Columns.{{$fcol}}.In(cols...)))

	{{$ftable.DownPlural}}, err := q.All(ctx, exec)
	if err != nil && !errors.Is(err, sql.ErrNoRows){
		return err
	}

	// Outer:
	for _, rel := range {{$ftable.DownPlural}} {
		for _, o := range os {
			if rel.{{$fcol}} == o.{{$col}} {
				o.R.{{$relAlias.Local}} = append(o.R.{{$relAlias.Local}}, rel)
				// continue Outer
			}
		}
	}

	return nil
}

{{end -}}
