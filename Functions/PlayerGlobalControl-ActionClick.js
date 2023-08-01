
// Action Click

(function() {
    const el = document.querySelector("{{ selector }}");
    let timeout = ('{{ timeout }}' === 'nil') ? 0 : Number('{{ timeout }}');
    console.log(el)
    if (el){
        if(timeout === 0){
            el.dispatchEvent(new CustomEvent('click'))
        } else {
            setTimeout(function(){
                el.dispatchEvent(new CustomEvent('click'))
            },timeout)
        }
    } else {
        console.log("no item to click")
    }
})();
