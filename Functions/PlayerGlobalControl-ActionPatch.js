(function () {
    const elList = Array.from(document.querySelectorAll("{{ selector }}"));
    if(elList.length == 0){
        console.log("no items found for: {{ selector }}" )
    }
    elList.forEach(el =>
        console.log(el)
    )
    elList.forEach((el, index) => {
        const childElement = el.querySelector("{{ childSelector }}")
        if (childElement && childElement.innerText) {
            el.dataset.contentInnerText = childElement.innerText;
            el.dataset.elementIndex = String(index);
        }
    })

})();

// Action Patch
