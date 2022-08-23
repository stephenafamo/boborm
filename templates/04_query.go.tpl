{{$tAlias := .Aliases.Table .Table.Name -}}

{{if .Table.IsView -}}
func {{$tAlias.UpPlural}}(mods ...bob.Mod[*psql.SelectQuery]) *model.ViewQuery[*{{$tAlias.UpSingular}}, {{$tAlias.UpSingular}}Slice] {
	return {{$tAlias.UpPlural}}View.Query(mods...)
}
{{- else -}}
func {{$tAlias.UpPlural}}(mods ...bob.Mod[*psql.SelectQuery]) *model.TableQuery[*{{$tAlias.UpSingular}}, {{$tAlias.UpSingular}}Slice, Optional{{$tAlias.UpSingular}}] {
	return {{$tAlias.UpPlural}}Table.Query(mods...)
}
{{- end}}

