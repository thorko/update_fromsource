<?php
require("Picture.php");
$path = "uploads/images/Umbau/thumbs";
$path_big = "uploads/images/Umbau";
$thumbs = array();

if ($handle = opendir($path_big)) {
	while ( false !== ($file = readdir($handle))) {
		if ( preg_match('/.*\.[jpg|JPG]/', $file)) {
			array_push($thumbs, $file);
		}
	}
}

closedir($handle);

$thumb = new Picture();

for($i = 0; $i < sizeof($thumbs); $i++) {
	if ( ! file_exists("$path/$thumbs[$i]") ){
		$thumb->createThumbs("$path_big/", "$path/", 150);
	}
	echo "<a href=\"$path_big/$thumbs[$i]\" class=\"highslide\" onclick=\"return hs.expand(this)\"><img src=\"$path/$thumbs[$i]\" alt=\"Highslide JS\" title=\"Click to enlarge\" /></a>\n";

}

?>
