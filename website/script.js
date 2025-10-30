const $ = (s,ctx=document)=>ctx.querySelector(s)
const $$ = (s,ctx=document)=>[...ctx.querySelectorAll(s)]

// Year
const yearEl = document.getElementById('year');
if(yearEl) yearEl.textContent = new Date().getFullYear()

// Motion budget: reduce on save-data/slow connection
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
const conn = navigator.connection || navigator.mozConnection || navigator.webkitConnection
const motionOK = !prefersReduced && !(conn && (conn.saveData || /2g|3g/.test(conn.effectiveType||'')))

function animateCounter(el){
  const target = parseInt(el.getAttribute('data-target')||'0',10)
  let start = 0
  const dur = 700
  const t0 = performance.now()
  const step = (t)=>{
    const p = Math.min(1, (t - t0)/dur)
    const val = Math.floor(start + (target - start) * (0.5 - Math.cos(Math.PI*p)/2))
    el.textContent = val.toLocaleString()
    if(p<1) requestAnimationFrame(step)
  }
  requestAnimationFrame(step)
}

// Unified observer for reveal + counters
const io = new IntersectionObserver((entries)=>{
  entries.forEach(e=>{
    if(e.isIntersecting){
      if(!motionOK){ e.target.style.transitionDuration='0s'; e.target.style.transitionDelay='0s' }
      e.target.classList.add('in')
      if(e.target.classList.contains('counter')) animateCounter(e.target)
      io.unobserve(e.target)
    }
  })
},{threshold:.12, rootMargin:'0px 0px -10% 0px'})
;[...document.querySelectorAll('.reveal, .counter')].forEach((el)=>{ io.observe(el) })

// Theme
const themeSaved = localStorage.getItem('theme') || 'dark'
document.documentElement.setAttribute('data-theme', themeSaved)
const themeBtn = document.getElementById('theme-toggle')
const setThemeIcon = (t)=>{ if(!themeBtn) return; themeBtn.textContent = t==='dark' ? '☾' : '☀︎' }
setThemeIcon(themeSaved)
if(themeBtn){
  themeBtn.addEventListener('click',()=>{
    const next = (document.documentElement.getAttribute('data-theme')==='dark')?'light':'dark'
    document.documentElement.setAttribute('data-theme', next)
    localStorage.setItem('theme', next)
    setThemeIcon(next)
  })
}

// i18n
const dict = {
  tr: {
'nav.features':'Özellikler','nav.screens':'Ekran Görüntüleri','nav.faq':'SSS','nav.contact':'İletişim',
    'how.title':'Nasıl çalışır?','how.step1.title':'Kayıt','how.step1.desc':'Ulaşım, enerji ve gıda kayıtlarını birkaç dokunuşla ekleyin.',
    'how.step2.title':'Analiz','how.step2.desc':'Günlük/aylık eğilimleri görün, hedefler belirleyin.',
    'how.step3.title':'Aksiyon','how.step3.desc':'Widget, Siri/CarPlay ve bildirimlerle alışkanlık kazanın.',
'hero.title':'Karbon ayak izinizi kolayca yönetin',
    'hero.subtitle':'Ulaşım, enerji ve gıda emisyonlarını birkaç dokunuşla kaydedin; hedefler belirleyin ve analitik içgörülerle azaltın.',
    'hero.appstore':'App Store','hero.playstore':'Google Play','hero.note':'Widget\'lar, Siri/CarPlay ve yerel bildirimlerle hızlı kayıt deneyimi.',
    'features.title':'Özellikler',
    'features.transport.title':'Ulaşım','features.transport.desc':'Toplu taşıma, yürüyüş, bisiklet, araç, uçuş: Türkiye odaklı emisyon katsayılarıyla doğru hesap.',
    'features.energy.title':'Enerji','features.energy.desc':'Elektrik ve doğal gaz tüketiminden kaynaklı emisyonları kolayca ekleyin ve analiz edin.',
    'features.food.title':'Gıda','features.food.desc':'Beslenme tercihlerinizi kaydedin; daha sürdürülebilir seçimler için öneriler alın.',
    'features.analytics.title':'Analitik','features.analytics.desc':'Günlük/haftalık/aylık eğilimler ve hedeflerle ilerlemenizi takip edin.',
    'features.gamification.title':'Oyunlaştırma','features.gamification.desc':'Başarımlar, hedefler ve rozetlerle motivasyonunuzu yüksek tutun.',
    'features.integrations.title':'Entegrasyonlar','features.integrations.desc':'Ana ekran widget\'ları, Siri/CarPlay ve yerel bildirim desteği.',
'demos.title':'Mini demolar','demos.quicklog':'Hızlı kayıt','demos.analytics':'Analitik','demos.widgets':'Widget',
    'screens.title':'Ekran Görüntüleri',
'faq.title':'Sıkça Sorulan Sorular','faq1.q':'Uygulama ücretsiz mi?','faq1.a':'Temel özellikler ücretsizdir. İleri seviye özellikler için daha sonra opsiyonel destek paketleri eklenebilir.',
    'faq2.q':'Verilerim güvende mi?','faq2.a':'Verileriniz yerel olarak saklanır ve isteğe bağlı olarak bulutla senkronize edilir. Gizlilik politikamıza uyumludur.',
    'faq3.q':'Veri senkronizasyonu nasıl çalışır?','faq3.a':'İsteğe bağlı hesap girişiyle kayıtlarınız cihazlar arasında senkronize edilebilir. İnternet yokken yerel kayıt devam eder, bağlantı geldiğinde eşitlenir.',
    'faq4.q':'Widget, Siri ve CarPlay desteği var mı?','faq4.a':'Evet. Ana ekran widget’ları hızlı erişim sağlar; Siri/CarPlay komutlarıyla eller serbest kayıt alabilirsiniz.',
    'faq5.q':'Verilerimi dışa aktarabilir miyim?','faq5.a':'Evet. Ayarlar bölümünden CSV/JSON dışa aktarma seçeneklerini kullanabilirsiniz.',
    'faq6.q':'Hedefleri nasıl ayarlarım?','faq6.a':'Analitik ekranından aylık/haftalık hedef belirleyebilir, ilerleme çubukları ve bildirimlerle takibini yapabilirsiniz.',
    'contact.title':'Bize Ulaşın','contact.name':'Ad Soyad','contact.email':'E-posta','contact.message':'Mesaj','contact.submit':'Gönder','contact.alt':'Veya:',
'footer.privacy':'Gizlilik','footer.press':'Basın Kiti',
    'impact.title':'Topluluk etkisi','impact.stat1':'Bu ay kaydedilen kg CO₂e','impact.stat2':'Toplu taşıma yolculuğu','impact.stat3':'Ağaç eşdeğeri tasarruf',
    'testimonials.title':'Kullanıcı yorumları','testimonials.q1':'“Günlük ulaşımımı kaydetmek çok hızlı, hedefler sayesinde azaltıyorum.”','testimonials.q2':'“Widget ve bildirimlerle alışkanlık oldu, aylık emisyonum düştü.”','testimonials.q3':'“Analitik ekranındaki içgörüler harika; yemek tercihlerimi değiştirdim.”',
    'newsletter.title':'Güncellemeleri alın','newsletter.placeholder':'E-postanızı girin','newsletter.submit':'Abone ol'
  },
  en: {
'nav.features':'Features','nav.screens':'Screens','nav.faq':'FAQ','nav.contact':'Contact',
    'how.title':'How it works','how.step1.title':'Log','how.step1.desc':'Add transport, energy and food logs in a few taps.',
    'how.step2.title':'Analyze','how.step2.desc':'See daily/monthly trends and set goals.',
    'how.step3.title':'Act','how.step3.desc':'Build habits with Widgets, Siri/CarPlay and notifications.',
'hero.title':'Manage your carbon footprint with ease',
    'hero.subtitle':'Log transport, energy and food in a few taps; set goals and reduce with analytics-driven insights.',
    'hero.appstore':'App Store','hero.playstore':'Google Play','hero.note':'Fast logging with Home Widgets, Siri/CarPlay and local notifications.',
    'features.title':'Features',
    'features.transport.title':'Transport','features.transport.desc':'Public transit, walking, cycling, car, flights: accurate factors tailored for Türkiye.',
    'features.energy.title':'Energy','features.energy.desc':'Add and analyze emissions from electricity and natural gas consumption.',
    'features.food.title':'Food','features.food.desc':'Record dietary choices and get tips for more sustainable options.',
    'features.analytics.title':'Analytics','features.analytics.desc':'Track progress with daily/weekly/monthly trends and goals.',
    'features.gamification.title':'Gamification','features.gamification.desc':'Stay motivated with achievements, goals and badges.',
    'features.integrations.title':'Integrations','features.integrations.desc':'Home widgets, Siri/CarPlay and local notification support.',
'demos.title':'Mini demos','demos.quicklog':'Quick log','demos.analytics':'Analytics','demos.widgets':'Widget',
    'screens.title':'Screenshots',
'faq.title':'Frequently Asked Questions','faq1.q':'Is the app free?','faq1.a':'Core features are free. Optional support packs may be added later for advanced features.',
    'faq2.q':'Is my data safe?','faq2.a':'Your data is stored locally and can optionally sync to the cloud. We comply with our privacy policy.',
    'faq3.q':'How does sync work?','faq3.a':'With optional sign-in, your logs sync across devices. Offline logging works and reconciles when back online.',
    'faq4.q':'Do you support Widgets, Siri and CarPlay?','faq4.a':'Yes. Home widgets provide quick access; with Siri/CarPlay you can log hands‑free.',
    'faq5.q':'Can I export my data?','faq5.a':'Yes. Use CSV/JSON export options in Settings.',
    'faq6.q':'How do I set goals?','faq6.a':'From Analytics set weekly/monthly goals and track via progress bars and notifications.',
    'contact.title':'Contact Us','contact.name':'Name','contact.email':'Email','contact.message':'Message','contact.submit':'Send','contact.alt':'Or:',
'footer.privacy':'Privacy','footer.press':'Press Kit','footer.terms':'Terms','footer.a11y':'Accessibility','footer.roadmap':'Roadmap',
    'impact.title':'Community impact','impact.stat1':'kg CO₂e logged this month','impact.stat2':'Public transit trips','impact.stat3':'Trees saved equivalent',
    'testimonials.title':'What users say','testimonials.q1':'“Logging daily transport is super fast, goals help me reduce.”','testimonials.q2':'“With widgets and notifications it became a habit; my monthly emissions dropped.”','testimonials.q3':'“Insights are great; I changed my dietary choices.”',
    'newsletter.title':'Get updates','newsletter.placeholder':'Enter your email','newsletter.submit':'Subscribe'
  }
}

const saved = localStorage.getItem('lang') || (navigator.language?.startsWith('tr')?'tr':'en')
let lang = saved
function applyI18n(){
  $$('[data-i18n]').forEach(el=>{
    const key = el.getAttribute('data-i18n')
    if(dict[lang] && dict[lang][key]) el.textContent = dict[lang][key]
  })
  $$('[data-i18n-placeholder]').forEach(el=>{
    const key = el.getAttribute('data-i18n-placeholder')
    if(dict[lang] && dict[lang][key]) el.setAttribute('placeholder', dict[lang][key])
  })
  document.documentElement.lang = lang
  const toggle = document.getElementById('lang-toggle')
  if(toggle) toggle.textContent = lang==='tr'?'EN':'TR'
}
applyI18n()

const langToggle = document.getElementById('lang-toggle')
if(langToggle){
  langToggle.addEventListener('click',()=>{
    lang = lang==='tr'?'en':'tr'
    localStorage.setItem('lang',lang)
    applyI18n()
  })
}
