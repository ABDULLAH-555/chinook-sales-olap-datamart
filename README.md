# Chinook Sales Data Warehouse & BI Data Mart

An end-to-end Data Warehousing project migrating the transactional **Chinook OLTP** database into an analytical **OLAP Star Schema** with a centralized **Business Intelligence (BI) Data Mart** in MySQL.

---

## 📌 Architecture & Dimensional Model

The data warehouse uses a **Star Schema** architecture designed around a central fact table and conformed dimensions:

* **Fact Table:** `Invoice_Fact` (Granularity: `InvoiceID` & `TrackID`)
* **Dimensions:**
  * `Customer_Dim` (SCD Type 1 with `CreateDate` and open-ended `UpdateDate`)
  * `Track_Dim` (Denormalized media metadata combining Tracks, Albums, Artists, and Genres)
  * `Date_Dim` (Contiguous calendar table generated via procedural loop covering 2009–2013)

### Star Schema Diagram
![Star Schema](assets/star_schema_diagram.png)

---

## 🛠️ Key Technical Features

1. **Schema Segregation:** Isolated analytical workloads in `chinook_olap` to prevent analytical contention on transactional OLTP systems.
2. **Kimball SCD1 Implementation:** Implemented audit timestamps (`CreateDate = CURRENT_TIMESTAMP`, `UpdateDate = '9999-12-31 23:59:59'`) directly inside the initial DDL.
3. **Product Hierarchy Denormalization:** Flattened 4-tier OLTP relations (`Track` ➔ `Album` ➔ `Artist` ➔ `Genre`) into `Track_Dim` using explicit `LEFT JOIN` operations to minimize downstream query cost.
4. **Automated ETL Pipeline:** Encapsulated migration logic inside modular MySQL Stored Procedures (`create_dim_customers`, `create_dim_tracks`, `create_dim_date`, `create_fact_invoice`).
5. **Referential Integrity:** Enforced Composite Primary Keys on `(InvoiceID, TrackID)` and Foreign Key constraints mapped to respective dimension primary keys.
6. **BI Data Mart View:** Deployed `Chinook_Datamart`—a consolidated reporting view enabling flat tabular access for Power BI and Tableau.

---

## 📊 Financial Reconciliation & Data Integrity

To guarantee zero data loss during extraction and aggregation, financial reconciliation was validated across the transactional source and data warehouse:

```sql
SELECT SUM(TotalAmount) AS OLAP_Total FROM chinook_olap.Invoice_Fact;
-- Result: $2,328.60

SELECT SUM(Total) AS OLTP_Total FROM Chinook_oltp.Invoice;
-- Result: $2,328.60
```
* **Status:** 100% matched ($2,328.60) with 0% data leakage.

---

## 🚀 How to Run

1. Ensure the `Chinook_oltp` database is loaded in your MySQL instance.
2. Run the migration script in MySQL Workbench or terminal:
   ```sql
   SOURCE chinook_OLAP_solution.sql;
   ```
3. Query the unified data mart view:
   ```sql
   USE chinook_olap;
   SELECT * FROM Chinook_Datamart LIMIT 10;
   ```
