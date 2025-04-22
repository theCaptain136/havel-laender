<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

// Read JSON input from Flutter
$data = json_decode(file_get_contents('php://input'), true);

if (!$data || !isset($data["title"]) || !isset($data["image_url"])) {
    echo json_encode(["status" => "error", "message" => "Missing data"]);
    exit;
}

// Load existing gallery.json
$file = 'gallery.json';
$gallery = file_exists($file) ? json_decode(file_get_contents($file), true) : [];

// Add new entry
$gallery[] = [
    "title" => htmlspecialchars($data["title"]),
    "image" => htmlspecialchars($data["image_url"])
];

// Save updated gallery
file_put_contents($file, json_encode($gallery, JSON_PRETTY_PRINT));

// Respond to the client
echo json_encode(["status" => "success"]);
?>
