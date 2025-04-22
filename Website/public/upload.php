<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

$targetDir = "images/";
$uploadOk = 1;

if (!isset($_FILES["file"])) {
    echo json_encode(["status" => "error", "message" => "No file uploaded."]);
    exit;
}

$fileName = basename($_FILES["file"]["name"]);
$targetFile = $targetDir . uniqid() . "_" . $fileName;
$imageFileType = strtolower(pathinfo($targetFile, PATHINFO_EXTENSION));

// Optional: Only allow certain file types
$allowedTypes = ["jpg", "jpeg", "png", "gif"];
if (!in_array($imageFileType, $allowedTypes)) {
    echo json_encode(["status" => "error", "message" => "Only image files allowed."]);
    exit;
}

if (move_uploaded_file($_FILES["file"]["tmp_name"], $targetFile)) {
    echo json_encode(["status" => "success", "image_url" => $targetFile]);
} else {
    echo json_encode(["status" => "error", "message" => "Upload failed."]);
}
?>
