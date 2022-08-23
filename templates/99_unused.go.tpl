// These packages may not be used in some models
var (
  _ = errors.Is(nil,nil)
  _ = strconv.Itoa(0)
  _ sql.Scanner = nil
  {{if .Table.IsView -}}
    _ context.Context = nil
    _ scan.Queryer = nil
    _ = omit.Val[int]{}
    _ = orm.Columns{}
  {{- end}}
)
