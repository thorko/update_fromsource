<?php
require("Picture.php");
$path_tumb = "vancouver/thumbs";
$path_pics = "vancouver";
$pics = array();

if ($handle = opendir($path_pics)) {
	while ( false !== ($file = readdir($handle))) {
		if ( preg_match('/.*\.[jpg|JPG]/', $file)) {
			array_push($pics, $file);
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

for($i = 0; $i < sizeof($pics); $i++) {
	if ( ! file_exists("$path/$pics[$i]") ){
		$thumb->createThumb("$path_pics/$pics[$i]", "$path_thumb/$pics[$i]", 150);
	}
	echo "<a href=\"$path_pics/$thumbs[$i]\" class=\"highslide\" onclick=\"return hs.expand(this, { captionEval: 'this.thumb.alt' })\"><img src=\"$path_thumb/$pics[$i]\" alt=\"".$thumb->getComment($path_pics/$pics[$i])."\" title=\"Click to enlarge\" /></a>\n";

}

?>
