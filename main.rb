require 'redis'
require 'oga'
require 'httparty'
require 'csv'

BASE_URL = 'http://www.bs-tbs.co.jp/sakaba/'
INDEX_PAGE_URL = 'http://www.bs-tbs.co.jp/sakaba/map/index.html'

IGNORE_IDS = [
  567, #赤坂サカス
  054, #ボルガ
  340, #河本（休業）
  196, #谷中鳥よし（情報なし）
]

def getPaths
  response = HTTParty.get(INDEX_PAGE_URL)
  html = response.body
  return [] if html.empty?
  html.encode!('UTF-8', 'CP932')
  document = Oga.parse_html(html)

  paths = []
  document.css('.kihon2 > a').each do |link|
    path = link.attributes.first.value.gsub(/\.\.\//, '').gsub(/(\r\n|\r|\n|\s)/, '')
    full_path = BASE_URL + path
    paths << full_path unless path.empty?
  end
  return paths
end

def getInfomations(paths)
  shop_infos = []
  paths.each do |path|
    p path
    response = HTTParty.get(path)
    html = response.body
    next if html.empty?
    html.encode!('UTF-8', 'CP932')
    document = Oga.parse_html(html)

    midashi = document.css('tr.midashi2 > td:first-child').text
    ko_midashi = document.css('span.kihon6').text + document.css('span.kihon4').text
    match = midashi.match(/^.+#(\d+).+「(.+)」/)
    next if match.nil?
    id = match[1]
    next if IGNORE_IDS.include?(id.to_i)

    original_name = match[2].gsub(/　/,'').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    closed = midashi.include?('閉店') || ko_midashi.include?('閉店')
    moved = midashi.include?('移転') || ko_midashi.include?('移転')
    name = original_name.clone
    name.insert(0, closed ? '[閉店]' : '').insert(0, moved ? '[移転]' : '')

    shop_info = {
      'ID' => id,
      '店名' => name,
    }
    info = document.css('span.kihon5').text

    # 住所
    address_match = info.match(/(住　所|住所).*：(\S+)(電話)?/)
    address = '不明'
    if address_match.nil?
      puts "[住所不明] #{path}" unless closed
      next
    else
      address = address_match[2].gsub(/　/,'').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    shop_info['住所'] = address

    # 電話番号
    tel_match = info.match(/(ＴＥＬ|電話|電　話|TEL).*：(\d+.{1}\d+.{1}\d+)/)
    tel = '不明'

    if tel_match.nil?
      puts "[TEL不明] #{path}" unless closed
    else
      tel = tel_match[2].tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    shop_info['電話番号'] = tel

    # 説明文
    description = ''
    document.css('td.kihon2 > p').each do |desc|
      description << desc.text
    end

    if description.empty?
      description << document.css('td.kihon2').text.split(/.*(住所|住　所).*/).first
    end

    if description.empty?
      puts "[DESC空] #{path}"
    end

    shop_info['説明'] = description.gsub(/(\r\n|\r|\n|\s)/, '').gsub('　',' ').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').strip
    shop_info['URL'] = path
    shop_infos << shop_info
    sleep 3
  end
  return shop_infos
end

paths = getPaths()
infos = getInfomations(paths)

CSV.open('result.csv', "wb") do |csv|
  csv << infos.first.keys
  infos.each do |hash|
    csv << hash.values
  end
end
