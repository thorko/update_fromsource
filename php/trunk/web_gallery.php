<?php
require("Picture.php");
$path = "vancouver/thumbs";
$path_big = "vancouver";
$thumbs = array();

if ($handle = opendir($path_big)) {
	while ( false !== ($file = readdir($handle))) {
		if ( preg_match('/.*\.[jpg|JPG]/', $file)) {
			array_push($thumbs, $file);
		}
	}
}

closedir($handle);
?>

   <script type="text/javascript" src="highslide-with-gallery.js"></script>
<link rel="stylesheet" type="text/css" href="highslide.css" />
<script type="text/javascript">
hs.graphicsDir = 'graphics/';
hs.align = 'center';
hs.transitions = ['expand', 'crossfade'];
hs.outlineType = 'rounded-white';
hs.fadeInOut = true;
//hs.dimmingOpacity = 0.75;

// Add the controlbar
hs.addSlideshow({
	//slideshowGroup: 'group1',
	interval: 5000,
	repeat: false,
	useControls: true,
	fixedControls: 'fit',
	overlayOptions: {
		opacity: 0.75,
		position: 'bottom center',
		hideOnMouseOut: true
	}
});

</script>

<?php
$thumb = new Picture();

for($i = 0; $i < sizeof($thumbs); $i++) {
	if ( ! file_exists("$path/$thumbs[$i]") ){
		$thumb->createThumbs("$path_big/", "$path/", 150);
	}
	echo "<a href=\"$path_big/$thumbs[$i]\" class=\"highslide\" onclick=\"return hs.expand(this)\"><img src=\"$path/$thumbs[$i]\" alt=\"Highslide JS\" title=\"Click to enlarge\" /></a>\n";

}

?>
