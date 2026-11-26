window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());

gtag('config', 'G-34LKXX2GN0');

window.trackGaPageView = function(path) {
  if (typeof gtag === 'function') {
    gtag('event', 'page_view', {
      'page_path': path,
      'page_title': document.title
    });
  }
};

window.trackMinesweeperEvent = function(eventName, difficulty, val) {
  if (typeof gtag === 'function') {
    gtag('event', eventName, {
      'event_category': 'Minesweeper',
      'difficulty': difficulty || 'Beginner',
      'value': val || 0
    });
  }
};
