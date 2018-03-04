require 'redis'
require 'oga'
require 'httparty'
require 'csv'
require 'unf'

BASE_URL = 'http://www.bs-tbs.co.jp/sakaba/'
INDEX_PAGE_URL = 'http://www.bs-tbs.co.jp/sakaba/map/index.html'

IGNORE_IDS = [
  '567', #赤坂サカス
  '054', #ボルガ
  '340', #河本（休業）
  '196', #谷中鳥よし（情報なし）
  '090', #高知「珍々亭」
  '100', #北千住「酒屋の酒場」
  '569', #東十条「三兼酒蔵」（閉店）
  '075', #赤羽岩淵「米山」（非公開）
]

WITHOUT_TEL_IDS = [
  '034',
  '084',
  '023',
  '020',
  '144',
  '061',
  '668',
  '075',
  '691',
  '824',
  '088',
  '766',
  '765',
  '359',
  '282',
  '190',
  '372',
  '245',
  '622',
  '183',
  '551',
  '734',
  '074',
  '611'
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
    if IGNORE_IDS.include?(id)
      #puts "[IGNORE_IDS] スキップ: #{path}"
      next
    end

    original_name = match[2].gsub(/　/,'').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    closed = midashi.include?('閉店') || ko_midashi.include?('閉店')
    moved = midashi.include?('移転') || ko_midashi.include?('移転')
    name = original_name.clone
    name.insert(0, closed ? '[閉店]' : '').insert(0, moved ? '[移転]' : '')

    if closed
      #puts "[閉店] スキップ: #{path}"
      next
    end

    shop_info = {
      'ID' => id,
      '店名' => name,
    }
    info = document.css("td span.kihon5").last.text

    # 住所
    address_match = info.match(/(住　所|住所).*：\s*(\S+)(電話)?/)
    address = '不明'
    if address_match.nil?
      puts "[住所不明] #{path}" unless closed
      next
    else
      address = address_match[2].gsub(/　/,' ').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end
    shop_info['住所'] = address

    # 電話番号
    if WITHOUT_TEL_IDS.include?(id)
      shop_info['電話番号'] = '不明 or 非公開'
      #puts "[WITHOUT_TEL_IDS] TELパースをスキップ: #{path}"
    else
      tel_match = info.match(/(ＴＥＬ|電話|電　話|TEL).*：\s*(\d+.{1}\d+.{1}\d+)/)
      tel = '不明'

      if tel_match.nil?
        puts "[TEL不明] #{path}" unless closed
      else
        tel = tel_match[2].tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
        tel = UNF::Normalizer.normalize(tel, :nfkc)
      end
      shop_info['電話番号'] = tel
    end

    # 説明文
    description = ''
    document.css('td.kihon2').first.children.each do |a|
      if a.kind_of?(Oga::XML::Text)
        description << a.text.gsub(/(\r\n|\r|\n|\s)/, '').gsub('　',' ').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').strip
      end
    end

    if description.empty?
      document.css('td.kihon2 > p').each do |a|
        description << a.text.gsub(/(\r\n|\r|\n|\s)/, '').gsub('　',' ').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').strip
      end
    end

    if description.empty?
      text = document.css('td.kihon2').text.split(/.*(住所|住　所).*/).first
      description << text.gsub(/(\r\n|\r|\n|\s)/, '').gsub('　',' ').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').strip
    end

    if description.empty?
      puts "[DESC空] #{path}"
    end

    shop_info['紹介文'] = description.gsub(/(\r\n|\r|\n|\s)/, '').gsub('　',' ').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').strip
    shop_info['URL'] = path
    shop_infos << shop_info
  end
  return shop_infos
end

paths = getPaths()
infos = getInfomations(paths)

CSV.open('result.csv', "wb") do |csv|
  csv << infos.first.keys
  infos.each do |hash|
    csv << hash.values.map {|value| UNF::Normalizer.normalize(value, :nfkc)}
  end
end
