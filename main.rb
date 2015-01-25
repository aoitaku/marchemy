require 'chipmunk'
require 'ayame'
require 'dxruby'
require 'forwardable'
require_relative './lib/animative'

ITEM_SOURCE = %w(
  fire_element:1
  water_element:1
  air_element:1
  earth_element:1
  water_bottle:2
  thunder_element:1
  ore:2
  ice_element:1
  plant:2
  harb:2
  leaf:2
  powder:2
  bread:64
  egg:32
  meat:32
  fish:32
  steak:128
  grape:32
  wine:128
  potion:256
  elixir:2048
  salt:32
  bacteria:2
  root:2
  mashroom:4
  pepper:2
  berry:16
  carrot:16
  gold:512
  electron:1024
  pearl:1024
  ruby:1024
  diamond:2048
)
RECIPE_SOURCE = [
  [:water_bottle, [:fire_element, :water_element]],
  [:thunder_element, [:fire_element, :air_element]],
  [:ore, [:fire_element, :earth_element]],
  [:ice_element, [:water_element, :air_element]],
  [:plant, [:water_element, :earth_element]],
  [:harb, [:leaf, :root]],
  [:leaf, [:plant, :earth_element]],
  [:powder, [:plant, :air_element]],
  [:bread, [:powder, :bacteria]],
  [:egg, [:fire_element, :bacteria]],
  [:meat, [:earth_element, :egg]],
  [:fish, [:water_element, :egg]],
  [:steak, [:meat, :fire_element]],
  [:grape, [:plant, :ice_element]],
  [:wine, [:grape, :bacteria]],
  [:potion, [:water_bottle, :harb]],
  [:elixir, [:wine, :potion]],
  [:salt, [:ore, :water_bottle]],
  [:bacteria, [:mashroom, :grape]],
  [:root, [:plant, :thunder_element]],
  [:mashroom, [:root, :air_element]],
  [:pepper, [:plant, :salt]],
  [:berry, [:grape, :fire_element]],
  [:carrot, [:root, :fire_element]],
  [:gold, [:ore, :elixir]],
  [:electron, [:thunder_element, :gold]],
  [:pearl, [:ice_element, :gold]],
  [:ruby, [:berry, :gold]],
  [:diamond, [:pearl, :ruby]],
  [:diamond, [:electron, :ruby]],
  [:diamond, [:electron, :pearl]]
]

class Universe

  extend Forwardable

  def_delegators :@space, :add_shape, :add_body, :remove_shape, :remove_body

  def initialize(gravity, height)
    @space = CP::Space.new
    @space.gravity = CP::Vec2.new(0, gravity)
    @body = CP::Body.new_static
    @body.p = CP::Vec2.new(0, 0)
    @shape = CP::Shape::Poly.new(
      @body,
      [[0, Window.height/2-height],
       [0, Window.height/2-1],
       [Window.width/2-1, Window.height/2-1],
       [Window.width/2-1, Window.height/2-height]
      ].map {|_| CP::Vec2.new(*_) },
      CP::Vec2.new(0, 0)
    )
    @shape.e = 0.33
    @shape.u = 1.0
    add_shape(@shape)
    [
      CP::Shape::Poly.new(
        @body,
        [[-16, 0],
         [-16, Window.height/2-1],
         [-1, Window.height/2-1],
         [-1, 0]
        ].map {|_| CP::Vec2.new(*_) },
        CP::Vec2.new(0, 0)
      ).tap {|shape|  shape.e = 0.75 ; shape.u = 0.33 },
      CP::Shape::Poly.new(
        @body,
        [[Window.width/2, 0],
         [Window.width/2, Window.height/2-1],
         [Window.width/2+15, Window.height/2-1],
         [Window.width/2+15, 0]
        ].map {|_| CP::Vec2.new(*_) },
        CP::Vec2.new(0, 0)
      ).tap {|shape|  shape.e = 0.75 ; shape.u = 0.33 }
    ].each(&method(:add_shape))
    @image = Sprite.new(
      0,
      Window.height/2-height,
      Image.new(Window.width/2, height, [0,67,255]).tap {|image|
        (height/16).times {|y|
          ((Window.width/2)/16).times {|x|
            image.box_fill(x*16, y*16, x*16+15, y*16+15, [0,47,191]) if (x + (y % 2)) % 2 == 0
          }
        }
      }.box(1, 1, Window.width/2-2, height-2, [255,255,255])
    )
    @image.target = RenderTarget.new(Window.width/2, Window.height/2)
  end

  def add_material(material)
    add_body(material.body)
    add_shape(material.shape)
  end

  def remove_material(material)
    remove_body(material.body)
    remove_shape(material.shape)
  end

  def update
    @space.step(1.0/60.0)
  end

  def render
    @image.draw
  end

  def render_target
    @image.target
  end

end

class Unit < Sprite

  attr_reader :body, :shape

  def initialize(x, y, image)
    super
    @body = CP::Body.new(1, CP::INFINITY)
    @body.p = CP::Vec2.new(x, y)
    @shape = CP::Shape::Circle.new(body, image.height / 2, CP::Vec2.new(0, 0))
    @shape.layers = 0b01
    self.collision = [image.width / 2, image.width / 2, image.width / 2]
  end

  def update
    self.x = body.p.x - image.width / 2
    self.y = body.p.y - image.height / 2
  end

  def render
    draw
  end

end

class Player < Unit

  include Animative

  attr_reader :direction, :hand, :material

  def initialize(x, y, image)
    super
    @body = CP::Body.new(10, CP::INFINITY)
    @body.p = CP::Vec2.new(x, y)
    @shape = CP::Shape::Circle.new(body, image.height / 2, CP::Vec2.new(0, 0))
    @shape.layers = 0b10
    @material = nil
    @hand = Sprite.new(x, y)
    @hand.collision = [8, 8, 8]
    self.collision = [image.width / 2, image.width / 2, image.width / 2]
  end

  def turn_left
    @direction = 0
  end

  def turn_right
    @direction = 1
  end

  def target=(render_target)
    super
    @hand.target = render_target
  end

  def update
    super
    self.x = body.p.x - image.width / 2
    self.y = body.p.y - image.height / 2
    hand.x = self.x
    hand.y = self.y - 2
  end

  def grab_material(material)
    material.body.v = CP::Vec2.new(0, 0)
    @material = material
    @hand.image = @material.image
  end

  def release_material
    @hand.image = nil
    @material.body.p = CP::Vec2.new(hand.x + @direction * 8, hand.y)
    @material.tap { @material = nil }
  end

  def render
    draw
    @hand.draw if @material
  end

end

class ItemData < Struct.new(:name, :score, :icon)
end

class Item

  extend Forwardable

  attr_reader :id, :data

  def_delegators :@data, :name, :score, :icon

  def initialize(data={})
    @id, @data = data.to_a.first
  end

end

class ItemDB

  include Enumerable

  extend Forwardable

  def_delegators :@data, :each

  def initialize(data)
    @data = data
  end

  def [](index)
    case index
    when Fixnum
      @data[index] ? Item.new({index => @data[index]}) : nil
    when Symbol
      (data = select {|_, i| next true if i.name == index.to_s}) ? Item.new(data) : nil
    end
  end

end

class RecipeDB

  extend Forwardable

  def_delegators :@recipes, :[]

  def initialize(recipes=[])
    @recipes = recipes
  end

  def find(*ingredients)
    found = self.match(*ingredients) and found.product
  end

  def match(*ingredients)
    @recipes.find {|recipe| recipe.match(*ingredients) }
  end

end

class Recipe

  attr_reader :product, :ingredients

  def initialize(product, ingredients)
    @product = product
    @ingredients = ingredients
  end

  def match(*ingredients)
    self.ingredients.sort == ingredients.sort
  end

end

class Medium < Unit

  extend Forwardable

  attr_reader :item

  def_delegators :@item, :id

  def initialize(x, y, item)
    @item = item
    super(x, y, @item.icon)
  end

  def self.pop(item)
    self.new(
      rand(Window.width/2-16)+8,
      -16,
      item
    )
  end

end

class GameData

  attr_accessor :score, :time
  attr_reader :player, :universe, :materials, :phenomenon, :item_db, :recipe_db

  def initialize
    @render_target = RenderTarget.new(Window.width/2,Window.height/2)
    @font = Font.new(12)
    prepare_db
    setup
  end

  def prepare_db
    item_images = Image.load_tiles(__dir__+"/gfx/item.png", 11, 3)
    @item_db = ItemDB.new(Hash[*(ITEM_SOURCE.map.with_index {|data, i|
      name, score = data.split(':')
      score = score.to_i
      [i+1, ItemData.new(name, score, item_images[i])]
    }).flatten])

    @recipe_db = RecipeDB.new(RECIPE_SOURCE.map {|product, ingredients|
      Recipe.new(@item_db[product].id, ingredients.map {|ingredient|
        @item_db[ingredient].id
      })
    })
  end

  def setup
    @score = 0
    @time = 600
    @timer = Fiber.new do
      loop do
        60.times { Fiber.yield }
        @time -= 1
      end
    end

    @universe = Universe.new(100, 80)
    @materials = []

    @phenomenon = Fiber.new do
      i = 0
      loop do
        i += 1
        @materials << Medium.pop(
          @item_db[[*1..4].sample]
        ).tap do |material|
          material.shape.e = 0.66
          material.shape.u = 0.33
          material.target = @universe.render_target
          @universe.add_material(material)
        end
        (120+@materials.size*2).times { Fiber.yield }
      end
    end

    animation_image = Image.load_tiles(__dir__+"/gfx/player.png", 4, 4)
    @player = Player.new(0, Window.height/2-92, animation_image[0]).tap do |player|
      player.turn_right
      player.animation_image = animation_image
      player.add_animation(:wait_right, 0, [8])
      player.add_animation(:wait_left, 0, [0])
      player.add_animation(:walk_right, 6, [9,10,11,10])
      player.add_animation(:walk_left, 6, [1,2,3,2])
      player.add_animation(:wait_right_handsup, 0, [12])
      player.add_animation(:wait_left_handsup, 0, [4])
      player.add_animation(:walk_right_handsup, 6, [13,14,15,14])
      player.add_animation(:walk_left_handsup, 6, [5,6,7,6])
      player.start_animation(:wait_right)
      player.shape.e = 0.1
      player.shape.u = 1.0
      player.target = universe.render_target
    end
    @universe.add_material(player)
  end

  def cleanup
    @score = 0
    @timer = nil
    @universe = nil
    @materials = []
    @phenomenon = nil
    @player = nil
  end

  def update
    @timer.resume
    return if @time <= 0
    phenomenon.resume if materials.size < 20
    player.body.apply_impulse(CP::Vec2.new(Input.x * 150, 0), CP::Vec2.new(0, 0))
    player.body.v = CP::Vec2.new(Input.x * 75, player.body.v.y) if player.body.v.x.abs > 75
    if Input.x < 0
      if player.material
        player.change_animation(:walk_left_handsup)
        player.turn_left
      else
        player.change_animation(:walk_left)
        player.turn_left
      end
    elsif Input.x > 0
      if player.material
        player.change_animation(:walk_right_handsup)
        player.turn_right
      else
        player.change_animation(:walk_right)
        player.turn_right
      end
    else
      if player.material
        player.change_animation([:wait_left_handsup, :wait_right_handsup][player.direction])
      else
        player.change_animation([:wait_left, :wait_right][player.direction])
      end
    end
    if Input.key_push?(K_Z)
      if player.material
        material = player.release_material
        universe.add_material(material)
        materials.push(material)
        material.body.apply_impulse(
          CP::Vec2.new(player.body.v.x + [-1,1][player.direction] * 33, -33),
          CP::Vec2.new(0, 0)
        )
      else
        materials.each do |material|
          if player.hand === material
            player.grab_material(material)
            universe.remove_material(material)
            materials.delete(material)
            break
          end
        end
      end
    end
    if Input.key_push?(K_X)
      if player.material
        materials.each do |material|
          if player.hand === material
            if found = recipe_db.find(material.id, player.material.id)
              universe.remove_material(material)
              materials.delete(material)
              old = player.release_material
              player.grab_material(Medium.new(
                old.x,
                old.y,
                item_db[found]
              ).tap {|material|
                material.body.apply_impulse(
                  CP::Vec2.new(player.body.v.x + [-1,1][player.direction] * 33, -33),
                  CP::Vec2.new(0, 0)
                )
                material.shape.e = 0.66
                material.shape.u = 0.33
                material.target = universe.render_target
              })
              break
            end
          end
        end
      end
    end
    if Input.key_push?(K_DOWN)
      if player.material
        material = player.release_material
        @score += material.item.data.score
      end
    end
    player.resume_animation
    universe.update
    player.update
    materials.each(&:update)
  end

  def render
    universe.render
    materials.each(&:render)
    player.render
    Window.draw_scale(Window.width/4, Window.height/4, universe.render_target, 2, 2)
    @render_target.draw_font(20, Window.height/2-60, 'TIME', @font, {color:[255,255,255]})
    @render_target.draw_font(Window.width/2-80, Window.height/2-60, 'SCORE', @font, {color:[255,255,255]})
    @render_target.draw_font(Window.width/2-20-@score.to_s.size*6, Window.height/2-40, @score.to_s, @font, {color:[255,255,255]})
    @render_target.draw_font(40+(20-@time.to_s.size*6), Window.height/2-40, @time.to_s, @font, {color:[255,255,255]})
    Window.draw_scale(Window.width/4, Window.height/4, @render_target, 2, 2)
  end

  def render_gameover
    @render_target.draw_font((Window.width/2-56)/2-12, (Window.height/2-12)/2+12, 'SCORE', @font, {color:[255,255,255]})
    @render_target.draw_font((Window.width/2-56)/2+(72-@score.to_s.size*6), (Window.height/2-12)/2+12, @score.to_s, @font, {color:[255,255,255]})
    @render_target.draw_font((Window.width/2-56)/2, (Window.height/2-12)/2-12, 'GAMEOVER', @font, {color:[255,255,255]})
    Window.draw_scale(Window.width/4, Window.height/4, @render_target, 2, 2)
  end

end

game_data = GameData.new

Window.mag_filter = TEXF_POINT
Window.loop do
  if game_data.time > 0
    game_data.update
    game_data.render
  else
    game_data.render_gameover
    if Input.key_push?(K_Z)
      game_data.setup
    end
  end
end

