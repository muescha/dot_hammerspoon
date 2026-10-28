const app = Application("{{ application }}");
const command = `{{ code }}`;
app.doJavaScript(command, { in: app.windows[0].currentTab() });
