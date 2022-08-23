{{- if not .Table.IsView -}}
{{$table := .Table}}
{{$tAlias := .Aliases.Table $table.Name -}}

func (o {{$tAlias.UpSingular}}Slice) DeleteAll(ctx context.Context, exec scan.Queryer) (int64, error) {
	return {{$tAlias.UpPlural}}Table.DeleteMany(ctx, exec, o...)
}

func (o {{$tAlias.UpSingular}}Slice) UpdateAll(ctx context.Context, exec scan.Queryer, vals Optional{{$tAlias.UpSingular}}) (int64, error) {
	o2, rowsAff, err := {{$tAlias.UpPlural}}Table.UpdateMany(ctx, exec, vals, o...)
	if err != nil {
		return rowsAff, err
	}

	for _, old := range o {
		for _, new := range o2 {
			{{range $column := $table.PKey.Columns -}}
			{{- $colAlias := $tAlias.Column $column -}}
			if new.{{$colAlias}} != old.{{$colAlias}} {
				continue
			}
			{{end -}}
			new.R = old.R
			*old = *new
			break
		}
	}

	return rowsAff, nil
}

func (o {{$tAlias.UpSingular}}Slice) ReloadAll(ctx context.Context, exec scan.Queryer) error {
	q := {{$tAlias.UpPlural}}()

	{{range $column := $table.PKey.Columns -}}
	{{- $colAlias := $tAlias.Column $column -}}
	{{$colAlias}}PK := make([]any, len(o))
		for i, o := range o {
			{{$colAlias}}PK[i] = o.{{$colAlias}}
		}
		q.Apply(psql.SelectQM.Where({{$tAlias.UpSingular}}Columns.{{$colAlias}}.In({{$colAlias}}PK...)))

	{{end}}

	o2, err := q.All(ctx, exec)
	if err != nil {
		return err
	}

	for _, old := range o {
		for _, new := range o2 {
			{{range $column := $table.PKey.Columns -}}
			{{- $colAlias := $tAlias.Column $column -}}
			if new.{{$colAlias}} != old.{{$colAlias}} {
				continue
			}
			{{end -}}
			new.R = old.R
			*old = *new
			break
		}
	}

	return nil
}

{{- end}}

