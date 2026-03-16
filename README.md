
# restaurant-smart-contract
Mananagement:
1.SetTax : set 
Restaurant Contracts
1.Management: cần gọi hàm grantRole để phân quyền ai là admin , nhân viên
chỉ dành cho admin:
-CreateStaff: tạo nhân viên
-UpdateStaffInfo: update thông tin nhân viên
-CreateTable: tạo bàn
-UpdateTable: update thông tin bàn
-CreateCategory: tạo loại món
-UpdateCategory: update loại món
-CreateDish: tạo món ăn
-UpdateDish: update thông tin món ăn
-CreateDiscount: tạo khuyến mãi
-UpdateDiscount: update thông tin khuyến mãi 
chỉ dành cho nhân viên
-UpdateDishStatus: nhân viên update tình trạng món còn hay hết
Các hàm lấy thông tin: nội dung như tên của hàm

2.Order: Cần gọi các hàm SetPOS,SetUsdt,SetMasterPool,SetTax,SetManangement trước.
-SetTax: set mức thuế
-MakeOrder: order món 
-UpdateOrder: thay đổi số lượng món của order đã gọi
-UpdateCourseStatus: nhân viên thay đổi trạng thaí của các món trong order
    PREPARING-đang nấu,
    SERVED-đã mang ra cho khách,
    CANCELED-món đã hủy
-PayUSDT: thanh toán = usdt
-ExecuteOrder: thanh toán = visa
-SetCallData : nhập vào input lấy ra id
-GetCallData : lấy id trên làm input lấy ra bytes để cho vào hàm  ExecuteOrder làm input
-ComfirmPayment: sau khi khách trả tiền thì nhân viên gọi để xác nhận thanh toán
-MakeReview: khách hàng review
Các hàm lấy thông tin: nội dung như tên của hàm






