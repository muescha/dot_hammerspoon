
// Action Get Property

(function() {
    const el = document.querySelector("{{ selector }}");
    return Array.from(el.parentNode.children).indexOf(el)
})();
