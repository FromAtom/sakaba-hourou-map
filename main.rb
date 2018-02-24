require 'redis'
require 'oga'
require 'httparty'

BASE_URL = 'http://www.bs-tbs.co.jp/sakaba/'
INDEX_PAGE_URL = 'http://www.bs-tbs.co.jp/sakaba/map/index.html'

def getPaths
  response = HTTParty.get(INDEX_PAGE_URL)
  html = response.body
  return [] if html.empty?
  html.encode!('UTF-8', 'CP932')
  document = Oga.parse_html(html)

  paths = []
  document.css('.kihon2 > a').each do |link|
    path = link.attributes.first.value.gsub(/\.\.\//, '')
    full_path = BASE_URL + path
    paths << full_path unless path.empty?
  end
  return paths
end

def getInfomations(paths)
  paths.each do |path|
    response = HTTParty.get(path)
    html = response.body
    next if html.empty?
    html.encode!('UTF-8', 'CP932')
    document = Oga.parse_html(html)

    midashi = document.css('tr.midashi2 > td:first-child').text
    match = midashi.match(/^.+#(\d+).+「(.+)」/)
    next if match.nil?
    id = match[1]
    original_name = match[2].gsub(/　/,'').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    closed = midashi.include?('閉店')
    moved = midashi.include?('移転')
    name = original_name.clone
    name.insert(0, closed ? '[閉店]' : '').insert(0, moved ? '[移転]' : '')

    shop_info = {
      :id => id,
      :name => name,
      :original_name => original_name,
      :closed => closed,
      :moved => moved
    }
    info = document.css('span.kihon5').text

    # 住所
    address_match = info.match(/(住　所|住所)：(\S+)(電話)?/)
    address = '不明'
    if address_match.nil?
      puts "[住所不明] #{path}"
    else
      address = match[2].gsub(/　/,'').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    shop_info[:address] = address

    # 電話番号
    tel_match = info.match(/(ＴＥＬ|電話|電　話|TEL)：(\d+.{1}\d+.{1}\d+)/)
    tel = '不明'
    if tel_match.nil?
      puts "[TEL不明] #{path}"
    else
      tel = tel_match[2].tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    shop_info[:tel] = tel

    # 説明文
    description = ''
    document.css('td.kihon2 > p').each do |desc|
      description << desc.text.strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end

    if description.empty?
      description << document.css('td.kihon2').first.text.strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    if description.empty?
      puts "[DESC空] #{path}"
    end

    shop_info[:description] = description
  end
end

paths = getPaths()
hoge = paths.first
getInfomations(paths)
