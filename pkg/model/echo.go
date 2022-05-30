package model

type Echo struct {
	Id   int64             `json:"id,omitempty"`
	Meta map[string]string `json:"Meta,omitempty"`
}

func (o Echo) JavaClassName() string {
	return "com.k8s.Echo"
}
