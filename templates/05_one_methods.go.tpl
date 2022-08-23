{{- if not .Table.IsView -}}
{{$table := .Table}}
{{$tAlias := .Aliases.Table $table.Name -}}

// Update uses an executor to update the {{$tAlias.UpSingular}}
func (o *{{$tAlias.UpSingular}}) Update(ctx context.Context, exec scan.Queryer, cols *orm.Columns) (int64, error) {
	o2, rowsAff, err := {{$tAlias.UpPlural}}Table.Update(ctx, exec, cols, o)
	if err != nil {
		return rowsAff, err
	}

	*o = *o2

	return rowsAff, nil
}

// Delete deletes a single {{$tAlias.UpSingular}} record with an executor
func (o *{{$tAlias.UpSingular}}) Delete(ctx context.Context, exec scan.Queryer) (int64, error) {
	return {{$tAlias.UpPlural}}Table.Delete(ctx, exec, o)
}

// Reload refreshes the {{$tAlias.UpSingular}} using the executor
func (o *{{$tAlias.UpSingular}}) Reload(ctx context.Context, exec scan.Queryer) error {
	o2, err := {{$tAlias.UpPlural}}Table.Query(
		{{range $column := $table.PKey.Columns -}}
		{{- $colAlias := $tAlias.Column $column -}}
		SelectWhere.{{$tAlias.UpPlural}}.{{$colAlias}}.EQ(o.{{$colAlias}}),
		{{end -}}
	).One(ctx, exec)
	if err != nil {
		return err
	}

	*o = *o2

	return nil
}

{{- end}}
