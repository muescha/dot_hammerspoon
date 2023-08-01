
// Action Select

(function() {
    const el = document.querySelector("{{ selector }}");

    if(el){
        el.focus()
    } else {
        console.log("no item to focus")
    }

    return el.id
})();
