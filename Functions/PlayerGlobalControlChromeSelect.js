
var chrome = Application("Google Chrome");

// JavaScript in JavaScript
// Hint: in IntelliJ IDEA you can inject a language into this string:
var command = `
    (function() {
        // console.log(document.activeElement.id)
        // Get First element (otherwise querySelectorAll)
        const elementWithId = document.querySelector("{{ selector }}");
        console.log(elementWithId)
        elementWithId.focus()
        return document.activeElement.id
    })();

`
chrome.windows[0].activeTab.execute({javascript:command})