{{$table := .Table}}
{{$tAlias := .Aliases.Table $table.Name -}}

{{if $table.IsView -}}
	var {{$tAlias.UpPlural}}View = model.NewView[*{{$tAlias.UpSingular}}, {{$tAlias.UpSingular}}Slice]({{quoteAndJoin .Schema $table.Name}})
{{- else -}}
var {{$tAlias.UpPlural}}Table = model.NewTable[*{{$tAlias.UpSingular}}, {{$tAlias.UpSingular}}Slice, Optional{{$tAlias.UpSingular}}]({{quoteAndJoin .Schema $table.Name}})
{{- end}}

var {{$tAlias.UpSingular}}Columns = struct {
	{{range $column := $table.Columns -}}
	{{- $colAlias := $tAlias.Column $column.Name -}}
	{{$colAlias}} psql.Expression
	{{end -}}
}{
	{{range $column := $table.Columns -}}
	{{- $colAlias := $tAlias.Column $column.Name -}}
	{{$colAlias}}: psql.Quote("{{$table.Name}}", "{{$column.Name}}"),
	{{end -}}
}

