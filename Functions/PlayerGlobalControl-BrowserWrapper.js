
var app = Application("{{ application }}");
var command = `{{ code }}`
app.windows[0].activeTab.execute({javascript:command})