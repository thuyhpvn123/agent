package main

// import (
// 	"encoding/json"
// 	// "fmt"
// 	"log"
// 	"os"
// 	"os/exec"
// 	"path/filepath"
// 	"strings"
// )
// /***
// solc --bin --abi contracts/agent.sol -o output_agent/   --base-path .   --include-path node_modules --via-ir --overwrite
// solc --bin --abi contracts/timekeeping.sol -o output_timekeeping/   --base-path .   --include-path node_modules --via-ir --overwrite

// ***/
// func main() {
// 	// Đường dẫn tới file Solidity
// 	solidityFile := "./contracts/agent.sol" // Thay bằng đường dẫn file của bạn
// 	compiler := "solcjs"                                    // Chọn solc hoặc solcjs
// 	version := "0.8.19"

// 	// Kiểm tra xem file có tồn tại hay không
// 	if _, err := os.Stat(solidityFile); os.IsNotExist(err) {
// 		log.Fatalf("File Solidity không tồn tại: %v", err)
// 	}

// 	// Tạo thư mục output nếu chưa tồn tại
// 	outputDir := "./output_timekeeping"
// 	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
// 		log.Fatalf("Không thể tạo thư mục output: %v", err)
// 	}

// 	// Kiểm tra compiler (solc hoặc solcjs)
// 	var cmd *exec.Cmd
// 	switch compiler {
// 	case "solc":

// 		cmd := exec.Command("solc", "--version")
// 		output, err := cmd.Output()
// 		if err != nil {
// 			log.Fatalf("Không thể kiểm tra phiên bản solc: %v", err)
// 		}
// 		if !strings.Contains(string(output), version) {
// 			log.Printf("Phiên bản hiện tại không phải %s. Đang chuyển sang %s...", version, version)
// 			switchCmd := exec.Command("solc-select", "use", version)
// 			if err := switchCmd.Run(); err != nil {
// 				log.Fatalf("Không thể chuyển sang phiên bản solc %s: %v", version, err)
// 			}
// 			log.Printf("Đã chuyển sang phiên bản solc %s.", version)
// 		} else {
// 			log.Printf("Đang sử dụng đúng phiên bản solc %s.", version)
// 		}

// 		cmd = exec.Command("solc", "--combined-json", "abi,bin", solidityFile)
// 	case "solcjs":

// 		cmd = exec.Command("solcjs", "--version")
// 		output, err := cmd.Output()
// 		if err != nil {
// 			log.Fatalf("Không thể kiểm tra phiên bản solc: %v", err)
// 		}
// 		if !strings.Contains(string(output), version) {
// 			log.Printf("Phiên bản hiện tại không phải %s. Đang chuyển sang %s...", version, version)
			
// 			log.Printf("Đang tải đúng phiên bản solcjs %s...", version)
// 			cmd := exec.Command("npm", "install", "-g", "solc@"+version)
// 			if err := cmd.Run(); err != nil {
// 				log.Fatalf("Không thể tải phiên bản solcjs %s: %v", version, err)
// 			}
// 			log.Printf("Đã tải thành công phiên bản solcjs %s.", version)

// 			log.Printf("Đã chuyển sang phiên bản solcjs %s.", version)
// 		} else {
// 			log.Printf("Đang sử dụng đúng phiên bản solcjs %s.", version)
// 		}


// 		// Lấy đường dẫn tuyệt đối cho file Solidity
// 		absSolidityFile, err := filepath.Abs(solidityFile)
// 		if err != nil {
// 			log.Fatalf("Không thể lấy đường dẫn tuyệt đối của file Solidity: %v", err)
// 		}

// 		// Chuyển vào thư mục output
// 		if err := os.Chdir(outputDir); err != nil {
// 			log.Fatalf("Không thể chuyển vào thư mục output: %v", err)
// 		}
// 		cmd = exec.Command("solcjs", "--bin", "--abi", "--optimize", "--optimize-runs", "200", absSolidityFile, "--base-path", ".", "--include-path", ".")
// 		log.Printf("Đang chạy lệnh: %s", cmd.String())

// 	default:
// 		log.Fatalf("Compiler không hợp lệ: %s. Chỉ hỗ trợ solc hoặc solcjs.", compiler)
// 	}

// 	// Chạy compiler
// 	output, err := cmd.Output()
// 	if err != nil {
// 		log.Fatalf("Lỗi khi chạy solcjs: %v\nOutput: %s", err, string(output))
// 	}

// 	// Nếu là solcjs, xử lý output từ các file
// 	if compiler == "solcjs" {

// 		// Chuyển vào thư mục output
// 		if err := os.Chdir("../"); err != nil {
// 			log.Fatalf("Không thể chuyển vào thư mục output: %v", err)
// 		}
// 		handleSolcJSOutput(filepath.Dir(solidityFile), outputDir)
// 		return
// 	}

// 	// Phân tích kết quả (solc output)
// 	var result map[string]interface{}
// 	if err := json.Unmarshal(output, &result); err != nil {
// 		log.Fatalf("Lỗi khi phân tích JSON: %v", err)
// 	}

// 	contracts := result["contracts"].(map[string]interface{})
// 	for name, contractData := range contracts {
// 		log.Printf("Contract: %s\n", name)
// 		data := contractData.(map[string]interface{})
// 		// Lấy ABI
// 		abi := data["abi"].(string)
// 		log.Println("ABI:")
// 		log.Println(abi)

// 		// Lấy bytecode
// 		bin := data["bin"].(string)
// 		log.Println("Bytecode:")
// 		log.Println(bin)

// 		// Ghi ABI và Bytecode vào file
// 		baseName := filepath.Base(name)
// 		abiFile := filepath.Join(outputDir, baseName+".abi.json")
// 		binFile := filepath.Join(outputDir, baseName+".bin")

// 		if err := os.WriteFile(abiFile, []byte(abi), 0644); err != nil {
// 			log.Printf("Lỗi khi ghi ABI: %v", err)
// 		}
// 		if err := os.WriteFile(binFile, []byte(bin), 0644); err != nil {
// 			log.Printf("Lỗi khi ghi Bytecode: %v", err)
// 		}
// 		log.Printf("Đã ghi ABI vào %s và Bytecode vào %s\n", abiFile, binFile)
// 	}
// }

// func handleSolcJSOutput(basePath string, outputDir string) {
// 	// SolcJS xuất ABI và bytecode vào file riêng
// 	log.Println("Xử lý output từ solcjs...")
// 	// Đường dẫn tới thư mục output

// 	// Đọc các file trong thư mục output
// 	files, err := os.ReadDir(outputDir)
// 	if err != nil {
// 		log.Fatalf("Không thể đọc thư mục output: %v", err)
// 	}

// 	// Duyệt qua các file và đổi tên
// 	for _, file := range files {
// 		oldName := file.Name()
// 		oldPath := filepath.Join(outputDir, oldName)

// 		// Bỏ tiền tố không mong muốn trong tên file
// 		newName := extractContractName(oldName)
// 		newPath := filepath.Join(outputDir, newName)

// 		// Đổi tên file
// 		if err := os.Rename(oldPath, newPath); err != nil {
// 			log.Printf("Không thể đổi tên file %s: %v", oldName, err)
// 		} else {
// 			log.Printf("Đã đổi tên file %s thành %s", oldName, newName)
// 		}
// 	}
// }

// // extractContractName: Lấy tên contract từ file gốc và tạo tên file mới
// func extractContractName(oldName string) string {
// 	// Ví dụ tên file: "_Users_nguyennam_per_go__..._LiquidityPoolFactory_sol_LiquidityPool.abi"
// 	// Giữ lại phần sau "sol_" và phần đuôi
// 	parts := strings.Split(oldName, "_sol_")
// 	if len(parts) > 1 {
// 		// Lấy phần sau "_sol_"
// 		return parts[1]
// 	}
// 	// Nếu không tìm thấy "_sol_", trả về tên gốc
// 	return oldName
// }