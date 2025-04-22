<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

$data = json_decode(file_get_contents('php://input'), true);

if (!isset($data["image_url"])) {
    echo json_encode(["status" => "error", "message" => "Missing image_url"]);
    exit;
}

$file = 'gallery.json';
if (!file_exists($file)) {
    echo json_encode(["status" => "error", "message" => "Gallery file not found."]);
    exit;
}

$gallery = json_decode(file_get_contents($file), true);

// Filter out the entry
$newGallery = array_filter($gallery, function ($item) use ($data) {
    return $item["image"] !== $data["image_url"];
});

file_put_contents($file, json_encode(array_values($newGallery), JSON_PRETTY_PRINT));

// Optionally delete image file (only if it's hosted on your server)
if (strpos($data["image_url"], 'images/') === 0 && file_exists($data["image_url"])) {
    unlink($data["image_url"]);
}

echo json_encode(["status" => "success"]);
