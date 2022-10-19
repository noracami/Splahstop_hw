# Splashtop_hw

## 回饋

- 思考 SQL / NoSQL 資料存取上方法的差異
- 非同步 / 讀寫分離資料庫 / 商業邏輯的副作用
- SFDC survey 需要更深入暸解

---

**A. 請試論述 SQL 與 NoSQL 在處理資料能力上的差別，並推論形成這些差異的可能原因。**

### SQL

- 可透過不同資料表間的關聯操作，取得想關注的資料
- 遵循 ACID 原則，確保資料一致性
- 避免同一資料同時出現在許多 Table

### NoSQL

- no schema 設計，平行擴增快
- 快速反應，非當下而是追求最後的一致性
- 一筆資料盡量儲存與之相關的資訊，反正規化

### 差別

由於 ACID 的特性，一般 SQL (關聯式資料庫)很適合處理數量敏感的交易，如金流、票務等
但受制於交易期間(transaction) 資料庫無法服務其他用戶，因此處理大量交易時速度比不上 NoSQL
NoSQL 的特性適合處理大量而比較不需要精準的數字，如社群按讚、即時數據視覺化
而 no schema 則適合新產品、概念發想時，迭代修改使用（便於修改架構、便於擴充）

---

**B. 請試著優化附件 interview_refactor_code_v7 的程式碼 。**

如附件

---

**C. 請試著回覆 面試考題 2022.txt 中的問題。**

**1. 小明要測試個 api, 當他執行第一次 API 成功, 但接下來執行第二次 API 時卻失敗, 請問你猜測失敗的原因有可能是什麼?**

first_time_return_success = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
second_time_return_error = SFDC.fetch_data(name: '武田製藥', age: 200, address:'台北市永和區中山路 66 巷', sex: 'Man', size: 'M')

可能的原因有

- 連線問題（連線不穩、連線數過多服務中斷）
- 對象服務異常（伺服器剛好壞掉）
- 呼叫使用的參數無法取得回應資料（沒有這筆資料）
- 權限問題（使用次數已達上限、所查詢資料需要額外權限）

---

**2. 延伸上題, 你猜測可能失敗的原因, 你會想要用什麼資料去試打 API 來驗證你猜測可能失敗的原因? (請試著用 rspec 來寫測試)**

如果是 API 主機問題，可直接重複呼叫已獲得正常回應的指令，確認主機狀態

因此針對 呼叫使用的參數無法取得回應資料（沒有這筆資料），可以觀察這兩筆資料差異點為

- name: 英文 與 中文
- age: 22 與 200
- address: 有到門牌號碼 與 只有到巷
- 多了 sex 與 size

因此我們可以一次改變一個參數，比對哪個（哪些）造成失敗回應

```ruby
RSpec.describe 'API TEST' do

   context 'change parameter' do
      it 'different name' do
         f1 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         f2 = SFDC.fetch_data(name: '武田製藥', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         expect(f1.status).to eq f2.status
      end

      it 'different age' do
         f1 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         f2 = SFDC.fetch_data(name: 'Peter', age: 200, address:'台北市大安區忠孝東路一段 66 號')
         expect(f1.status).to eq f2.status
      end

      it 'different address' do
         f1 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         f2 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市永和區中山路 66 巷')
         expect(f1.status).to eq f2.status
      end
   end

   context 'add parameter' do
      it 'add sex' do
         f1 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         f2 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號', sex: 'Man')
         expect(f1.status).to eq f2.status
      end

      it 'add size' do
         f1 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號')
         f2 = SFDC.fetch_data(name: 'Peter', age: 22, address:'台北市大安區忠孝東路一段 66 號', size: 'M')
         expect(f1.status).to eq f2.status
      end
   end
end
```

---

**3. 請試著去了解 Salesforce 這家公司提供的 Apex REST api. 請試著解釋 Salesforce 是做何用途? 為何要使用 APEX api ? (請詳述你的理解過程)**

Salesforce 是一家 雲端客戶關係管理系統供應商，Salesforce.com（SF dot com, SFDC）提供瀏覽器即可開啟使用的企業軟體平台，並讓客戶依需求預算決定租用的方案。
在此背景下，Salesforce 於 2006 推出 APEX 語言，一種類似 JAVA 的強型別、物件導向的程式語言，並具有 workflow 的概念，順暢的與資料庫操作，並可接受其系統網站程式、使用者ＵＩ點擊，或是 API 方式互動。
使用 Apex REST API，除了是自身開發語言可符合自己需求外，以 API 方式傳遞資料，可專注於資料本身，發揮該公司關係管理、分析的強項，公開的 API 也能促進有能力有意願者建立起生態系，形成正向循環。

---

**4. 假設你有一個 5000 萬筆資料的 user_logs table.**

```
今天假如我想要刪除 user_logs 的 updated_at < 1.year.ago (約有 500 萬筆).

請寫出一個 rake 去刪除這些 500 萬筆的資料.
(提示: 請使用對 db 與 system 系統影響越小與最有效率的方式去撰寫.在不考慮停機的情況下)

環境: 該資料庫環境有讀寫分離. 只要是使用 where, Rails 都會連到 readonly 主機, 但是執行 delete 時會自動切到. write 主機.

UserLog.where("updated_at < ?", 1.year.ago)
...
...
...
```

假設這些 logs 都是寫入當下就不會再更動，因此可期待 紀錄 會按時間排序，並假設這些紀錄刪除不會影響到資料庫其他資料表（無其他資料表外部鍵指向它）
因此，使用 `find_in_batches` 分批取出，並以 `delete`（不會呼叫 callback）刪除之

```ruby
namespace :user_logs do
   desc "delete logs"
   task :delete => :environment do
      period = 1.year.ago
      UserLog.where("updated_at < ?", period).find_in_batches do |rows|
         # p cc = rows.last.id
         UserLog.delete(rows.map(&:id))
         # UserLog.destroy(rows.map(&:id))
         # p UserLog.find_by(id: cc).nil?
      end
   end
end
```

---

## Ref

### https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dev_guide.htm

### https://github.com/slim-template/slim
