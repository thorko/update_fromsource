<?php
class Picture {

	public function createThumb( $picture, $thumb, $thumbWidth ) {
	    // parse path for the extension
	    $info = pathinfo($picture);
	    // continue only if this is a JPEG image
	    if ( strtolower($info['extension']) == 'jpg' || strtolower($info['extension']) == 'JPG' )
	    {
	      //echo "Creating thumbnail for {$fname} <br />";
	
	      // load image and get image size
	      $img = imagecreatefromjpeg( "{$picture}" );
	      $width = imagesx( $img );
	      $height = imagesy( $img );
	
	      // calculate thumbnail size
	      $new_width = $thumbWidth;
	      $new_height = floor( $height * ( $thumbWidth / $width ) );
	
	      // create a new temporary image
	      $tmp_img = imagecreatetruecolor( $new_width, $new_height );
	
	      // copy and resize old image into new image
	      imagecopyresized( $tmp_img, $img, 0, 0, 0, 0, $new_width, $new_height, $width, $height );
	
	      // save thumbnail into a file
	      imagejpeg( $tmp_img, "$thumb" );
	    }
	}

	public function getComment( $picture ) {
		$comment = exif_read_data($picture, 'COMMENT');
		// return only first comment for now
		return	$comment['COMMENT'][0];
	}
}
?>
