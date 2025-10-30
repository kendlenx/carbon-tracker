const $ = (s,ctx=document)=>ctx.querySelector(s)
const $$ = (s,ctx=document)=>[...ctx.querySelectorAll(s)]

// Year
$('#year').textContent = new Date().getFullYear()

// i18n
const dict = {
  tr: {
    'nav.features':'Özellikler','nav.screens':'Ekran Görüntüleri','nav.faq':'SSS','nav.contact':'İletişim',
    'hero.title':'Karbon ayak izinizi takip edin ve azaltın',
    'hero.subtitle':'Ulaşım, enerji, gıda ve alışveriş kaynaklı emisyonlarınızı kaydedin; hedefler belirleyin, içgörüler alın, başarımlar kazanın.',
    'hero.appstore':'App Store','hero.playstore':'Google Play','hero.note':'Widget\'lar, Siri/CarPlay ve yerel bildirimlerle hızlı kayıt deneyimi.',
    'features.title':'Özellikler',
    'features.transport.title':'Ulaşım','features.transport.desc':'Toplu taşıma, yürüyüş, bisiklet, araç, uçuş: Türkiye odaklı emisyon katsayılarıyla doğru hesap.',
    'features.energy.title':'Enerji','features.energy.desc':'Elektrik ve doğal gaz tüketiminden kaynaklı emisyonları kolayca ekleyin ve analiz edin.',
    'features.food.title':'Gıda','features.food.desc':'Beslenme tercihlerinizi kaydedin; daha sürdürülebilir seçimler için öneriler alın.',
    'features.analytics.title':'Analitik','features.analytics.desc':'Günlük/haftalık/aylık eğilimler ve hedeflerle ilerlemenizi takip edin.',
    'features.gamification.title':'Oyunlaştırma','features.gamification.desc':'Başarımlar, hedefler ve rozetlerle motivasyonunuzu yüksek tutun.',
    'features.integrations.title':'Entegrasyonlar','features.integrations.desc':'Ana ekran widget\'ları, Siri/CarPlay ve yerel bildirim desteği.',
    'screens.title':'Ekran Görüntüleri',
    'faq.title':'Sıkça Sorulan Sorular','faq1.q':'Uygulama ücretsiz mi?','faq1.a':'Temel özellikler ücretsizdir. İleri seviye özellikler için daha sonra opsiyonel destek paketleri eklenebilir.',
    'faq2.q':'Verilerim güvende mi?','faq2.a':'Verileriniz yerel olarak saklanır ve isteğe bağlı olarak bulutla senkronize edilir. Gizlilik politikamıza uyumludur.',
    'contact.title':'Bize Ulaşın','contact.name':'Ad Soyad','contact.email':'E-posta','contact.message':'Mesaj','contact.submit':'Gönder','contact.alt':'Veya:',
    'footer.privacy':'Gizlilik','footer.press':'Basın Kiti'
  },
  en: {
    'nav.features':'Features','nav.screens':'Screens','nav.faq':'FAQ','nav.contact':'Contact',
    'hero.title':'Track and reduce your carbon footprint',
    'hero.subtitle':'Log emissions from transport, energy, food and shopping; set goals, get insights and earn achievements.',
    'hero.appstore':'App Store','hero.playstore':'Google Play','hero.note':'Fast logging with Home Widgets, Siri/CarPlay and local notifications.',
    'features.title':'Features',
    'features.transport.title':'Transport','features.transport.desc':'Public transit, walking, cycling, car, flights: accurate factors tailored for Türkiye.',
    'features.energy.title':'Energy','features.energy.desc':'Add and analyze emissions from electricity and natural gas consumption.',
    'features.food.title':'Food','features.food.desc':'Record dietary choices and get tips for more sustainable options.',
    'features.analytics.title':'Analytics','features.analytics.desc':'Track progress with daily/weekly/monthly trends and goals.',
    'features.gamification.title':'Gamification','features.gamification.desc':'Stay motivated with achievements, goals and badges.',
    'features.integrations.title':'Integrations','features.integrations.desc':'Home widgets, Siri/CarPlay and local notification support.',
    'screens.title':'Screenshots',
    'faq.title':'Frequently Asked Questions','faq1.q':'Is the app free?','faq1.a':'Core features are free. Optional support packs may be added later for advanced features.',
    'faq2.q':'Is my data safe?','faq2.a':'Your data is stored locally and can optionally sync to the cloud. We comply with our privacy policy.',
    'contact.title':'Contact Us','contact.name':'Name','contact.email':'Email','contact.message':'Message','contact.submit':'Send','contact.alt':'Or:',
    'footer.privacy':'Privacy','footer.press':'Press Kit'
  }
}

const saved = localStorage.getItem('lang') || (navigator.language?.startsWith('tr')?'tr':'tr')
let lang = saved
function applyI18n(){
  $$('[data-i18n]').forEach(el=>{
    const key = el.getAttribute('data-i18n')
    if(dict[lang] && dict[lang][key]) el.textContent = dict[lang][key]
  })
  document.documentElement.lang = lang
  const toggle = document.getElementById('lang-toggle')
  toggle.textContent = lang==='tr'?'EN':'TR'
}
applyI18n()

document.getElementById('lang-toggle').addEventListener('click',()=>{
  lang = lang==='tr'?'en':'tr'
  localStorage.setItem('lang',lang)
  applyI18n()
})
