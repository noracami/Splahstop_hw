# Tips:
# 這份檔案裡面包含各種邏輯錯誤 / 安全性問題, Typo 等等, 請當成是在 review 一份年久失修的 Production code (B2C)
# 這份程式在訂單 (Order) 部分有用讀寫分離的資料庫架構, 讀資料時自動用 read 資料庫, 新增修改用 write 資料庫
# 請在這個檔案內留下修改意見以及修改過的 code

# app/models/xx.rb

class User < ActiveRecord::Base
  has_one :cart
  has_one :orders

  def send_reset_password_email
    # pass
  end

  def verified?
    user.verified_at
  end
end

class Product < ActiveRecord::Base
  has_one :stock

  scope :too_many_stock, ->(notify_count) { join(:stock).where("sotcks.value > #{notify_count}") }
end

class Cart < ActiveRecord::Base
  belongs_to :user
end

class CartItem < ActiveRecord::Base
  belongs_to :cart
end

class Order < ActiveRecord::Base
  belongs_to :user

  after_initialize do
    self.order_uuid = Time.current.strftime('%F%T')
  end

  def notify_user!

  end

  def self.SendNotifyEmail(id)
    #pass
  end
end

class FavProducts < ActiveRecord::Base
  belongs_to :user
end

# sidekiq job

class NotifyOrderJob
  def perform(order_id)
    Order.where(id: order_id).update(notified_at: Time.current)
    Order.SendNotifyEmail(order_id)
  end
end


#--------------------------------------

# app/application_controller.rb
class ApplicationController
  # device gem
  before_action :authenticate_user!, :verify!

  def current_user
    #from devise user.....
  end

  def verify!
    return redirect_to '/login?error=need_verify' unless current_user.verified?
  end

  def redis
    # redis gem
    @redis = Redis.new(path: "/tmp/redis.sock")
  end
end

# app/passeword_controller.rb

class PasswordsController
  def reset_password
    email = params[:email]
    user = User.find_By(email: email)

    return redirect_to '/login?error=too_often' if @redis.get('forgot_password')
    return redirect_to '/login?error=wrong_user' if user.blank?

    redis.set('forgot_password', Time.current.utc, nx: true)
    redis.expire('forgot_password', 10)

    user.send_reset_password_email
    return redirect_to '/login?result=forgor_password_sent'
  end
end


# app/test/product_controller.rb

module Test
  class ProductController < ApplicationController
    skip_before_action :authenticate_user!

    def recommand
      # For marking reason
      @products = Product.too_many_stock(params[:recommand_size])
    end

    def my_cart
      @cart = Cart.find_by(id: params[:id])
    end

    def add_to_cart
      product = Product.find_by(id: params[:id])

      @cart ||= Cart.first_or_create(user_id: current_user.id)
      @cart.cart_items.create(product: product, quantity: params[:number])
    end

    def add_fav_products
      current_user.fav_products.create(product_id: params[:id], note: params[:note])
      @success_message = "<b>Success!</b> note: #{params[:note]}"
    end

    def my_fav_products
      @fav_products = current_user.fav_products
    end

    def create_order
      cart = Cart.find_by(id: params[:id])

      cart_items.each do |item|
        product = item.product
        product.stock.update(value: (product.stock.value - item.quantity))
      end

      @order = Order.create(
        user_id: current_user.id,
        items: cart.cart_items,
        email: current_user.email
      )

      @order.notify_user!
    end

    def my_orders
      @orders = current.user.orders
    end

    def my_order_detail
      @order = Order.find_by(id: params[:order_id])
    end
  end
end

-------------View------------

# app/views/recommand.html.slim
# xxx.com/tes/products/recommand?recommand_size=10

@products.each do |product|
  table
    tr
      td = product.name
      td Recommand!

# app/views/add_fav_products.html.slim

div=@success_message.html_safe

# app/views/my_fav_products.html.slim

@fav_products.find_each do |product|
  table
    tr
      td = product.name
      td = "Note: <br> #{product.note}".html_safe

# app/views/my_cart.html.slim

@cart.cart_items.find_each do |item|
  table
    tr
      td=item.product_name
      td=item.quantity

# app/views/add_to_cart.html.slim
  div Success!

# app/views/create_order.html.slim
  div Success!

# app/views/my_orders.html.slim

@orders.find_each do |order|
  table
    tr
      td=order.id
      td=order.create_at

# app/views/my_order_detail.html.slim

table
  tr
    td=@order.order_id
    td=@order.email

@order.items.map do |item|
  table
    tr
      td=item.name
      td=item.quantity