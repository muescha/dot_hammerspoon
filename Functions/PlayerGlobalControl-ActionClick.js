
// Action Click

(function() {
    // console.log(document.activeElement.id)
    // Get First element (otherwise querySelectorAll)
    const elementWithId = document.querySelector("{{ selector }}");
    console.log(elementWithId)
    elementWithId.click()
    return document.activeElement.id
})();
