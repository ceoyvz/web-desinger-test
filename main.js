document.addEventListener("DOMContentLoaded", function () {
    // 1. güncel yılı footer dinamik yazma
    const curremtYearSpan = document.getElementById("güncel-yil");
    if (curremtYearSpan) {
        const currentYear = new Date().getFullYear();
        curremtYearSpan.textContent = currentYear;
    }

    //2. basit bir buton etkileşimi ekleme 
    // index.html bir buton elementi olusturun
    const denemeButonu = document.getElementById("deneme-butonu");
    if (denemeButonu) {
        denemeButonu.addEventListener("click", function () {
            alert("Butona tıklandı!");
        });
    }

    console.log("Web sitesi yüklendi!");
});