class OpportunityScraper
  BASE_URI = "http://mars.nasa.gov/mer/gallery/all/"

  def initialize
    @rover = Rover.find_by(name: "Opportunity")
  end

  SOL_SELECT_CSS_PATHS = [
    "#Engineering_Cameras_Navigation_Camera",
    "#Engineering_Cameras_Panoramic_Camera",
    "#Engineering_Cameras_Microscopic_Imager",
    "select[id^=Engineering_Cameras_Entry]",
    "#Engineering_Cameras_Front_Hazcam",
    "#Engineering_Cameras_Rear_Hazcam"
  ]

  CAMERAS = {
    f: "FHAZ",
    r: "RHAZ",
    n: "NAVCAM",
    p: "PANCAM",
    m: "MINITES",
    e: "ENTRY"
  }

  def scrape
    collect_sol_paths
  end

  def main_page
    Nokogiri::HTML(open(BASE_URI + "opportunity.html"))
  end

  def sol_paths
    paths = Array.new
    SOL_SELECT_CSS_PATHS.each do |s|
      select = main_page.css(s).first
      select.css("option").each do |option|
        paths << option.attributes["value"].value
      end
    end
    paths
  end

  def collect_sol_paths
    sol_paths.each do |path|
      regex = /(?<camera>\w)(?<sol>\d+)/.match(path)
      sol = regex[:sol]
      camera_name = CAMERAS[regex[:camera].to_sym]
      camera = @rover.cameras.find_by(name: camera_name)
      photos = Photo.where(rover: @rover, sol: sol, camera: camera)
      if !photos.any?
        begin
          collect_image_paths(path)
        rescue => e
          Rails.logger.info e
          Rails.logger.info path
          next
        end
      end
    end
  end

  def collect_image_paths(sol_path)
    photos_page = Nokogiri::HTML(open(BASE_URI + sol_path))
    photo_links = photos_page.css("tr[bgcolor='#F4F4E9']").map { |p| p.css("a") }
    photo_links.each do |links|
      links.each do |link|
        create_photos(link)
      end
    end
  end

  def create_photos(link)
    path = link.attributes["href"].value
    parts = path.split("/")
    sol = parts[2].to_i
    camera_name = CAMERAS[parts[1].to_sym]
    camera = @rover.cameras.find_by(name: camera_name)
    photo_page = Nokogiri::HTML(open(BASE_URI + path))
    early_path = path.scan(/\d\/\w\/\d+\//).first
    src = BASE_URI + early_path +
      photo_page.css("table[width='500'] img").first.attributes["src"].value
    p = Photo.find_or_create_by(sol: sol, camera: camera,
                                img_src: src, rover: @rover)
    Rails.logger.info "Photo with id #{p.id} created from #{p.rover.name}"
    Rails.logger.info "img_src: #{p.img_src}, sol:" +
      "#{p.sol}, camera: #{p.camera}"
  end
end
