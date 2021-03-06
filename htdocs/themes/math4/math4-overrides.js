/* This is the override file for math4.js.  If you copy 
 * math4-overrides.js.dist to math4-overrides.js you can edit the
 * values contained in this file and they will override the css values 
 * normally used for math4.  This includes anything you can accomplish with
 * jQuery and provides a lot of flexibility.  
 *
 * If you upgrade your machine this file will not be overwritten, however, the 
 * math4.js and math4-overrides.js.dist file may change.  If this happens it
 * may cause problems with your theme until your reconcile the changes with 
 * your modifactions here.  (Similar to how localOverrides.conf works.) 
 */


$(function () {

/* This changes the WeBWorK Logo on the top left to a new image */
//    $('.webwork_logo a img').attr('src','new-path-here');

/* This changes the MAA Logo on the top to a new image */
$('.institution_logo a img').attr('src','/webwork2_files/themes/math4/images-custom/maa_logo_small_black.png');

$('#mainform input[type="reset"]').addClass('btn btn-small');
$('#mainform input[name="edit_local"]').removeClass('btn-primary');
$('#mainform input[name="new_local_set"]').removeClass('btn-primary');
$('#mainform input[name="lib_view"]').addClass('btn-primary');
$('#mainform input[name="lib_view_bpl"]').addClass('btn-primary');
$('#mainform input[name="lib_view_bplen"]').addClass('btn-primary');
$('#mainform input[name="view_mysets_set"]').addClass('btn-primary');
$('#mainform input[name="view_local_set"]').addClass('btn-primary');
$('#mainform input[name="lib_view_spcf"]').addClass('btn-primary');
$('#mainform input[name="view_setdef_set"]').addClass('btn-primary');
$('#mainform select[name=max_shownt]').addClass('input-small').removeClass('input-xxlarge');
});
