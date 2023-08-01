
// Action Click

(function() {

    const el = document.querySelector("{{ selector }}");
    let timeout = ('{{ timeout }}' === 'nil') ? 0 : Number('{{ timeout }}');

    if (el){
        if(timeout === 0){
            el.click()
        } else {
            setTimeout(function(){
                el.click()
            },timeout)
        }
    } else {
        console.log("no item to click")
    }
})();
