# Tips:
# 這份檔案裡面包含各種邏輯錯誤 / 安全性問題, Typo 等等, 請當成是在 review 一份年久失修的 Production code (B2C)
# 這份程式在訂單 (Order) 部分有用讀寫分離的資料庫架構, 讀資料時自動用 read 資料庫, 新增修改用 write 資料庫
# 請在這個檔案內留下修改意見以及修改過的 code

# app/models/xx.rb

# class User < ActiveRecord::Base
# 繼承自 ApplicationRecord, 以下同
class User < ApplicationRecord
  has_one :cart
  # has_one :orders
  # 可同時擁有多筆訂單, 補上fav_products關聯
  has_many :orders
  has_many :fav_products
  has_many :products, through: :fav_products

  def send_reset_password_email
    # pass
  end

  def verified?
    user.verified_at
  end
end

# class Product < ActiveRecord::Base
class Product < ApplicationRecord
  has_one :stock
  has_many :fav_products
  has_many :users, through: :fav_products

  # scope :too_many_stock, ->(notify_count) { join(:stock).where("sotcks.value > #{notify_count}") }
  # sql 查詢命令使用參數而不是字串，避免 injection 風險
  scope :too_many_stock, ->(notify_count) { join(:stock).where("sotcks.value > ?", notify_count) }
end

# class Cart < ActiveRecord::Base
class Cart < ApplicationRecord
  belongs_to :user
  has_many :cart_items
end

# class CartItem < ActiveRecord::Base
class CartItem < ApplicationRecord
  belongs_to :cart
  has_one :product
end

# class Order < ActiveRecord::Base
class Order < ApplicationRecord
  belongs_to :user
  # 補上關聯
  has_many :items, class_name: "CartItem", foreign_key: "cart_items_id"

  # after_initialize do
  after_create do
    # self.order_uuid = Time.current.strftime('%F%T')
    # 以秒為單位太粗糙，容易產生重複的 uuid，往下再取6位
    self.order_uuid = Time.current.strftime('%F%T.%6N')
  end

  def notify_user!
    # 寄信
  end

  def self.SendNotifyEmail(id)
    #pass
  end
end

# class FavProducts < ActiveRecord::Base
#
#
class FavProduct < ApplicationRecord
  belongs_to :user
  belongs_to :product
end

# sidekiq job

class NotifyOrderJob
  def perform(order_id)
    # Order.where(id: order_id).update(notified_at: Time.current)
    # order_id 只會有一筆，用find
    Order.find(order_id).update(notified_at: Time.current)
    Order.SendNotifyEmail(order_id)
  end
end


#--------------------------------------

# app/application_controller.rb
# class ApplicationController
#
#
class ApplicationController < ActionController::Base
  # device gem
  # 加上 :verify!, :redis
  before_action :authenticate_user!, :verify!, :redis

  def current_user
    #from devise user.....
  end

  def verify!
    return redirect_to '/login?error=need_verify' unless current_user.verified?
  end

  def redis
    # redis gem
    # @redis = Redis.new(path: "/tmp/redis.sock")
    # memoization
    @redis ||= Redis.new(path: "/tmp/redis.sock")
  end
end

# app/passeword_controller.rb

# class PasswordsController
# 繼承devise
class Users::PasswordsController < Devise::PasswordsController
  def reset_password
    email = params[:email]
    # user = User.find_By(email: email)
    # typo
    user = User.find_by(email: email)

    return redirect_to '/login?error=too_often' if @redis.get('forgot_password')
    
    # 註 rails 有幫 nil 加上 :blank? 方法
    return redirect_to '/login?error=wrong_user' if user.blank?

    # redis.set('forgot_password', Time.current.utc, nx: true)
    # redis.expire('forgot_password', 10)
    @redis.set('forgot_password', Time.current.utc, nx: true)
    @redis.expire('forgot_password', 10)

    user.send_reset_password_email
    return redirect_to '/login?result=forgor_password_sent'
  end
end


# app/test/product_controller.rb

module Test
  class ProductController < ApplicationController
    # skip_before_action :authenticate_user!
    skip_before_action :authenticate_user!, :verify!

    def recommand
      # For marking reason
      @products = Product.too_many_stock(params[:recommand_size])
    end

    def my_cart
      # @cart = Cart.find_by(id: params[:id])
      @cart = Cart.find(params[:id])
    end

    def add_to_cart
      # product = Product.find_by(id: params[:id])
      product = Product.find(params[:id])

      # @cart ||= Cart.first_or_create(user_id: current_user.id)
      # 要找user的cart，從整個Cart找會找到其他人的
      @cart ||= current_user.cart.first_or_create
      @cart.cart_items.create(product: product, quantity: params[:number])
    end

    def add_fav_products
      current_user.fav_products.create(product_id: params[:id], note: params[:note])
      # views 要過濾 html 字元
      @success_message = "<b>Success!</b> note: #{params[:note]}"
    end

    def my_fav_products
      # @fav_products = current_user.fav_products
      # n + 1
      @fav_products = current_user.fav_products.include(:product)
    end

    def create_order
      cart = Cart.find_by(id: params[:id])

      # cart_items.each do |item|
      cart.cart_items.each do |item|
        product = item.product
        # modles/stock.rb 可以加上 validates :value, numericality: { greater_than_or_equal_to: 0 }
        product.stock.update(value: (product.stock.value - item.quantity))
      end

      @order = Order.create(
        user_id: current_user.id,
        items: cart.cart_items,
        email: current_user.email
      )

      # 建立成功，通知使用者
      @order.notify_user!
    end

    def my_orders
      # @orders = current.user.orders
      # typo
      @orders = current_user.orders
    end

    def my_order_detail
      # @order = Order.find_by(id: params[:order_id])
      @order = Order.find(params[:order_id])
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

# div=@success_message.html_safe
# 過濾 html 字元
div = sanitize @success_message

# app/views/my_fav_products.html.slim

@fav_products.find_each do |product|
  table
    tr
      td = product.name
      # td = "Note: <br> #{product.note}".html_safe
      td = sanitize "Note: <br> #{product.note}"

# app/views/my_cart.html.slim

@cart.cart_items.find_each do |item|
  table
    tr
      # td=item.product_name
      # td=item.quantity
      td = item.product_name
      td = item.quantity


# app/views/add_to_cart.html.slim
  div Success!

# app/views/create_order.html.slim
  div Success!

# app/views/my_orders.html.slim

@orders.find_each do |order|
  table
    tr
      # td=order.id
      # td=order.create_at
      td = order.id
      td = order.create_at

# app/views/my_order_detail.html.slim

table
  tr
    # td=@order.order_id
    # td=@order.email
    td = @order.order_id
    td = @order.email

@order.items.map do |item|
  table
    tr
      # td=item.name
      # td=item.quantity
      td = item.name
      td = item.quantity
