require 'chipmunk'
require 'ayame'
require 'dxruby'
require 'forwardable'
require_relative './lib/animative'

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
      Image.new(Window.width/2, height, [255,255,255])
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
    hand.x = self.x + [-1,1][@direction] * 8
    hand.y = self.y
  end

  def glab_material(material)
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

item_db = ItemDB.new(Hash[*(%w(
  fire_element:1
  water_element:1
  air_element:1
  earth_element:1
  steam:2
  thunder_element:2
  rock:2
  ice_element:2
  tree:2
  sand:2
).map.with_index {|data, i|
  name, score = data.split(':')
  [i+1, ItemData.new(name, score, Image.new(16,16).circle_fill(8,8,8,[255,255,255]))]
}).flatten])

recipe_db = RecipeDB.new([
  [item_db[:steam].id, [item_db[:fire_element].id, item_db[:water_element].id]],
  [item_db[:thunder_element].id, [item_db[:fire_element].id, item_db[:air_element].id]]
].map {|product, ingredients| Recipe.new(product, ingredients)})

universe = Universe.new(100, 32)
materials = []

phenomenon = Fiber.new do
  i = 0
  loop do
    i += 1
    materials << Medium.pop(
      item_db[1]
    ).tap do |material|
      material.shape.e = 0.66
      material.shape.u = 0.33
      material.target = universe.render_target
      universe.add_material(material)
    end
    60.times { Fiber.yield }
  end
end

animation_image = Image.load_tiles("gfx/player.png", 4, 4)
player = Player.new(0, Window.height/2-44, animation_image[0]).tap do |player|
  player.turn_right
  player.animation_image = animation_image
  player.add_animation(:wait_right, 0, [8])
  player.add_animation(:wait_left, 0, [0])
  player.add_animation(:walk_right, 6, [9,10,11,10])
  player.add_animation(:walk_left, 6, [1,2,3,2])
  player.start_animation(:wait_right)
  player.shape.e = 0.1
  player.shape.u = 1.0
  player.target = universe.render_target
end
universe.add_material(player)

Window.mag_filter = TEXF_POINT
Window.loop do
  phenomenon.resume
  player.body.apply_impulse(CP::Vec2.new(Input.x * 150, 0), CP::Vec2.new(0, 0))
  player.body.v = CP::Vec2.new(Input.x * 75, player.body.v.y) if player.body.v.x.abs > 75
  if Input.x < 0
    player.change_animation(:walk_left)
    player.turn_left
  elsif Input.x > 0
    player.change_animation(:walk_right)
    player.turn_right
  else
    player.change_animation([:wait_left, :wait_right][player.direction])
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
          player.glab_material(material)
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
            material = Medium.new(
              old.x,
              old.y,
              item_db[found]
            ).tap do |material|
              material.shape.e = 0.66
              material.shape.u = 0.33
              material.target = universe.render_target
            end
            universe.add_material(material)
            materials.push(material)
            material.body.apply_impulse(
              CP::Vec2.new(0, -50),
              CP::Vec2.new(0, 0)
            )
            break
          end
        end
      end
    end
  end
  player.resume_animation
  universe.update
  player.update
  materials.each(&:update)
  universe.render
  player.render
  materials.each(&:render)
  Window.draw_scale(Window.width/4, Window.height/4, universe.render_target, 2, 2)
end

