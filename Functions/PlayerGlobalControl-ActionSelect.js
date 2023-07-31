
// Action Select

(function() {
    // console.log(document.activeElement.id)
    console.log(document.activeElement)
    // Get First element (otherwise querySelectorAll)
    const elementWithId = document.querySelector("{{ selector }}");
    console.log(elementWithId)

    elementWithId.focus()

    console.log(document.activeElement)
    return document.activeElement.id
})();
