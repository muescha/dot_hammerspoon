const app = Application("{{ application }}");
const command = `{{ code }}`;
app.windows[0].activeTab.execute({javascript: command})