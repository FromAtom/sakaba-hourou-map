require 'redis'
require 'oga'
require 'open-uri'

BASE_URL = 'http://www.bs-tbs.co.jp/sakaba/'
INDEX_PAGE_URL = 'http://www.bs-tbs.co.jp/sakaba/map/index.html'

def getPaths
  html = open(INDEX_PAGE_URL).read
  html.encode!('UTF-8', 'CP932')
  document = Oga.parse_html(html)

  paths = []
  document.css('.kihon2 > a').each do |link|
    path = link.attributes.first.value.gsub(/\.\.\//, '')
    paths << path
    # title = link.children.text.gsub(/(\r\n|\r|\n)/, '')
    # /\A#(\d+)[\s　]([\S\s]+)\z/ =~ title
    # id = $1
    # shop_name = $2
  end
end
