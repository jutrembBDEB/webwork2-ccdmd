(function() {
	var basicRequestObject = {
		"xml_command": "listLib",
		"library_name": "Library",
		"command": "buildtree"
	};

	var basicWebserviceURL = "/webwork2/instructorXMLHandler";

	$(document).ready(function(){

	  $('[name="search_bplen"]').tagsinput({typeahead: { source: function(query) { return []; }, freeInput: false }});
	  $('[name="search_bpl"]').tagsinput({typeahead: { source: function(query) { return []; }, freeInput: false }});

	  $('input[name="search_bpl"]').on('itemRemoved', function(event) {
	     blib_update('count', 'clear');
	     $("#library_defkeywords").val(20);
	     lib_searchops();
	     lib_top20keywords();
	  });
	  $('input[name="search_bplen"]').on('itemRemoved', function(event) {
	     benlib_update('count', 'clear');
	     $("#library_defkeywordsen").val(20);
	     enlib_searchops();
	     enlib_top20keywords();
	  });
	  $('input[name="search_bplen"]').on('itemAdded', function(event) {
	     benlib_update('count', 'clear');
	     $("#library_defkeywordsen").val(20);
	     enlib_searchops();
	     enlib_top20keywords();
	  });
	  $('input[name="search_bpl"]').on('itemAdded', function(event) {
	     blib_update('count', 'clear');
	     $("#library_defkeywords").val(20);
	     lib_searchops();
	     lib_top20keywords();
	  });
	   if($('[name="library_lib"] option:selected').index() == 0) {
	      $("#lib_view_spcf").attr("disabled","disabled");
	   }

	   $("#blibrary_subjects").change ( function() {

	       blib_update('chapters', 'get');
	       blib_update('count', 'clear' );

	       lib_searchops();
	       $("#library_defkeywords").val(20);
	       lib_top20keywords();
	       return true;
	   });
	   $("#benlibrary_subjects").change ( function() {

	       benlib_update('chapters', 'get');
	       benlib_update('count', 'clear' );

	       enlib_searchops();
	       $("#library_defkeywordsen").val(20);
	       enlib_top20keywords();
	       return true;
	   });


	   $("#blibrary_chapters").change ( function() {
	       lib_searchops();
	       blib_update('count', 'clear');
	       $("#library_defkeywords").val(20);
	       lib_top20keywords();
	       return true;
	   });
	   $("#benlibrary_chapters").change ( function() {
	       enlib_searchops();
	       benlib_update('count', 'clear');
	       $("#library_defkeywordsen").val(20);
	       enlib_top20keywords();
	       return true;
	   });
	lib_searchops();
	lib_top20keywords();
	enlib_searchops();
	enlib_top20keywords();
	  $("#search_bpl").hide();
	  $("#search_bplen").hide();

	  $('input[name=reset]').click(function() {
	       var brw = $('[name="bbrowse_which"]').val();
	       var k = 0;
	       if(brw == 'browse_spcf_library') {
	           k = 6;
	       }
	       f_reset(k);
	       return false;
	  });

	  $("#load_kw").click(function() {
	       f_loadmore();
	       return false;
	  });
	  $("#load_kwen").click(function() {
	       f_loadmoreen();
	       return false;
	  });

	  //OPL Advanced search handle
	  $("#library_advanced").click(function (event) {
	        adv = $('[name="library_adv_btn"]').val();
	        if(adv == 2) {
	            $(this).val(maketext('Advanced Search'));
	            $('[name="library_adv_btn"]').val('1');
	            //change index
	            $('[name="library_textbook"]').prop("selectedIndex",0);
	            $('#opladv tr.opladvsrch').toggle(false);
	            $('#opladv span.opladvsrch').toggle(false);
	            lib_update('count','clear');
	        } else {
	            $('[name="library_adv_btn"]').val('2');
	            $(this).val(maketext('Basic Search'));
	            $('#opladv tr.opladvsrch').toggle(true);
	            $('#opladv span.opladvsrch').toggle(true);
	        }
	        event.preventDefault();
	   });
	   
	   $('.nav-tabs a').on('show.bs.tab', function(e) {
	   	localStorage.setItem('activeTab', $(e.target).attr('href'));
	   	k = $(e.target).closest('li').index();
	   	$('[name="lib_deftab"]').val(k);
	   	setBrowseWhich(k);
	   	toggleAdvSrch();
	   	f_reset(k);
	   });  
	});

	function f_tags(arr) {
		$('[name="search_bpl"]').tagsinput('destroy');
		$('[name="search_bpl"]').tagsinput({typeahead: { source: function(query) { return arr; }, freeInput: false }});
	}

	function f_tagsen(arr) {
		$('[name="search_bplen"]').tagsinput('destroy');
		$('[name="search_bplen"]').tagsinput({typeahead: { source: function(query) { return arr; }, freeInput: false }});
	}

	function f_loadmore() {
	       var k = parseInt($("#library_defkeywords").val()) + 20;
	       $("#library_defkeywords").val(k);
	       lib_top20keywords();
	       return false;
	}

	function f_loadmoreen() {
	       var k = parseInt($("#library_defkeywordsen").val()) + 20;
	       $("#library_defkeywordsen").val(k);
	       enlib_top20keywords();
	       return false;
	}

	function f_reset(v) {
	       nomsg();
     
	       $('[name="showHints"]').prop('checked', 0);
	       $('[name="showSolutions"]').prop('checked', 0);
	       $('#max_shownt').prop("selectedIndex",20);

	       $('[name="library_subjects"]').prop("selectedIndex",0);
	       lib_update('chapters', 'clear');
	       lib_update('count', 'clear' );
	       $('[name="library_textbook"]').prop("selectedIndex",0);
	       $('[name="library_textchapter"]').prop("selectedIndex",0);
	       $('[name="library_textsection"]').prop("selectedIndex",0);
	       $('[name="llibrary_sets"]').prop("selectedIndex",0);
	       $('[name="mlibrary_sets"]').prop("selectedIndex",0);
	       $('[name="slibrary_sets"]').prop("selectedIndex",0);
       
	       if(v != 2) {$('[name="library_adv_btn"]').val(1);}

	       $('[name="blibrary_subjects"]').prop("selectedIndex",0);
	       blib_update('chapters', 'clear');
	       $('input[name="search_bpl"]').tagsinput('removeAll');
	       lib_searchops();

	       $('[name="benlibrary_subjects"]').prop("selectedIndex",0);
	       benlib_update('chapters', 'clear');
	       $('input[name="search_bplen"]').tagsinput('removeAll');
	       enlib_searchops();

	       $("#library_defkeywords").val(20);
	       $("#lib_deftab").val(v);
	       lib_top20keywords();

	       $("#library_defkeywordsen").val(20);
	       $("#lib_deftab").val(v);
	       enlib_top20keywords();

	       $('[name="library_lib"]').prop("selectedIndex",0);
	       $("#lib_view_spcf").attr("disabled","disabled");
	       dir_update('dir', 'clear' );
	       blib_update('count', 'clear');
	       benlib_update('count', 'clear');

	       $(".showResultsMenu").hide().css("visibility", "hidden");
	       $('#showResults').hide().css("visibility", "hidden");
		$(".well").css("display", "none");
	       $(".psr_render_area").css("display", "none");
	       $(".RenderSolo").css("display", "none");
	       $(".lb-mlt-group").css("visibility", "hidden");
	       $(".AuthorComment").css("display", "none");
	       $('#showResultsEnd').hide().css("visibility", "hidden");
	}

	function setBrowseWhich(i) {
		if(i == 0)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_bpl_library';
		if(i == 1)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_bplen_library';
		if(i == 2)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_npl_library';
		if(i == 3)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_local';
		if(i == 4)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_mysets';
		if(i == 5)
			document.getElementsByName('bbrowse_which')[0].value = 'browse_setdefs';
		if(i == 6)
			document.getElementsByName('bbrowse_which')[0].value  = 'browse_spcf_library';
		return;
	}
	
	function toggleAdvSrch() {
		var advbt = $('[name="library_adv_btn"]').val();
		if(advbt == 2) {
			$("#library_advanced").val(maketext('Basic Search'));
			$('#opladv tr.opladvsrch').toggle(true);
			$('#opladv span.opladvsrch').toggle(true);
		} else {
			$("#library_advanced").val(maketext('Advanced Search'));
			$('#opladv tr.opladvsrch').toggle(false);
			$('#opladv span.opladvsrch').toggle(false);
		}
	}
	
	// Messaging

	function nomsg() {
		$(".Message").html("");
	}

	function goodmsg(msg) {
		$(".Message").html('<div class="ResultsWithoutError">'+msg+"</div>");
	}

	function badmsg(msg) {
		$(".Message").html('<div class="ResultsWithError">'+msg+"</div>");
	}

	function init_webservice(command) {
		var myUser = $('#hidden_user').val();
		var myCourseID = $('#hidden_courseID').val();
		var mySessionKey = $('#hidden_key').val();
		var mydefaultRequestObject = {};
		$.extend(mydefaultRequestObject, basicRequestObject);
		if (myUser && mySessionKey && myCourseID) {
			mydefaultRequestObject.user = myUser;
			mydefaultRequestObject.session_key = mySessionKey;
			mydefaultRequestObject.courseID = myCourseID;
		} else {
			alert("missing hidden credentials: user "
				+ myUser + " session_key " + mySessionKey+ " courseID "
				+ myCourseID, "alert-error");
			return null;
		}
		mydefaultRequestObject.xml_command = command;
		return mydefaultRequestObject;
	}

	function lib_update(who, what) {
		var child = { subjects : 'chapters', chapters : 'sections', sections : 'count'};

		//nomsg();
		var all = 'All ' + capFirstLetter(who);
		all = maketext(all);

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}

		typ = 'OPL';

		var subj = $('[name="library_subjects"] option:selected').val();
		var chap = $('[name="library_chapters"] option:selected').val();
		var sect = $('[name="library_sections"] option:selected').val();

		var subjind = $('[name="library_subjects"] option:selected').index();
		var chapind = $('[name="library_chapters"] option:selected').index();
		var sectind = $('[name="library_sections"] option:selected').index();
		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};
		if(sectind == 0) { sect = '';};

		var lib_text = $('[name="library_textbook"] option:selected').val();
		var lib_textchap = $('[name="library_textchapter"] option:selected').val();
		var lib_textsect = $('[name="library_textsection"] option:selected').val();

		var lib_textind = $('[name="library_textbook"] option:selected').index();
		var lib_textchapind = $('[name="library_textchapter"] option:selected').index();
		var lib_textsectind = $('[name="library_textsection"] option:selected').index();
		if(lib_textind == 0) { lib_text = '';};
		if(lib_textchapind == 0) { lib_textchap = '';};
		if(lib_textsectind == 0) { lib_textsect = '';};

		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_sections = sect;
		mydefaultRequestObject.library_srchtype = typ;
		mydefaultRequestObject.library_textbooks = lib_text;
		mydefaultRequestObject.library_textchapter = lib_textchap;
		mydefaultRequestObject.library_textsection = lib_textsect;
		if(who == 'count') {
			mydefaultRequestObject.command = 'countDBListings';
			// console.log(mydefaultRequestObject);
			return $.ajax({type:'post',
				url: basicWebserviceURL,
				data: mydefaultRequestObject,
				timeout: 100000, //milliseconds
				success: function (data) {
					if (data.match(/WeBWorK error/)) {
						reportWWerror(data);		   
					}

					var response = $.parseJSON(data);
					// console.log(response);
					var arr = response.result_data;
					arr = arr[0];
					var line = maketext("There are") + " " + arr + " " + maketext("matching WeBWorK problems")
					if(arr == "1") {
						line = maketext("There is 1 matching WeBWorK problem")
					}
					$('#library_count_line').html(line);
					return true;
				},
				error: function (data) {
					alert('338 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
				},
			});

		}
		var subcommand = "getAllDBchapters";
		if(what == 'clear') {
			setselect('library_'+who, [all]);
			return lib_update(child[who], 'clear');
		}
		if(who=='chapters' && subj=='') { return lib_update(who, 'clear'); }
		if(who=='sections' && chap=='') { return lib_update(who, 'clear'); }
		if(who=='sections') { subcommand = "getSectionListings";}
		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				// console.log(response);
				var arr = response.result_data;
				arr.splice(0,0,all);
				setselect('library_'+who, arr);
				lib_update(child[who], 'clear');
				return true;
			},
			error: function (data) {
				alert('371 setmaker.js: ' + basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function blib_update(who, what) {
		var child = { subjects : 'chapters', chapters : 'sections', sections : 'count'};

		//nomsg();
		var all = 'All ' + capFirstLetter(who);
		all = maketext(all);

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}

		var typ = 'BPL';

		var subj = $('[name="blibrary_subjects"] option:selected').val();
		var chap = $('[name="blibrary_chapters"] option:selected').val();
		var subjind = $('[name="blibrary_subjects"] option:selected').index();
		var chapind = $('[name="blibrary_chapters"] option:selected').index();
		var keywd = $('[name="search_bpl"]').val();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		mydefaultRequestObject.blibrary_subjects = subj;
		mydefaultRequestObject.blibrary_chapters = chap;
		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_srchtype = typ;
		mydefaultRequestObject.library_keywords = keywd;

		if(who == 'count') {
			mydefaultRequestObject.command = 'countDBListings';
			// console.log(mydefaultRequestObject);
			return $.ajax({type:'post',
				url: basicWebserviceURL,
				data: mydefaultRequestObject,
				timeout: 100000, //milliseconds
				success: function (data) {
					if (data.match(/WeBWorK error/)) {
						reportWWerror(data);		   
				       }

				       var response = $.parseJSON(data);
				       // console.log(response);
				       var arr = response.result_data;
				       arr = arr[0];
				       var line = maketext("There are") + " " + arr + " " + maketext("matching WeBWorK problems")
				       if(arr == "1") {
					   line = maketext("There is 1 matching WeBWorK problem")
				       }
				       $('#blibrary_count_line').html(line);
				       return true;
				},
				error: function (data) {
				alert('432 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
				},
			});
		}
		var subcommand = "getAllDBchapters";
		if(what == 'clear') {
			setselect('blibrary_'+who, [all]);
			return blib_update(child[who], 'clear');
		}
		if(who=='chapters' && subj=='') { return blib_update(who, 'clear'); }
		if(who=='sections' && chap=='') { return blib_update(who, 'clear'); }
		if(who=='sections') { subcommand = "getSectionListings";}
		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
			       	reportWWerror(data);
			       }

			       var response = $.parseJSON(data);
			       // console.log(response);
			       var arr = response.result_data;
			       arr.splice(0,0,all);
			       setselect('blibrary_'+who, arr);
			       blib_update(child[who], 'clear');
			       return true;
			},
			error: function (data) {
				alert('464 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function benlib_update(who, what) {
		var child = { subjects : 'chapters', chapters : 'sections', sections : 'count'};

		//nomsg();
		var all = 'All ' + capFirstLetter(who);
		all = maketext(all);

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}

		var typ = 'BPLEN';

		var subj = $('[name="benlibrary_subjects"] option:selected').val();
		var chap = $('[name="benlibrary_chapters"] option:selected').val();
		var subjind = $('[name="benlibrary_subjects"] option:selected').index();
		var chapind = $('[name="benlibrary_chapters"] option:selected').index();
		var keywd = $('[name="search_bplen"]').val();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		mydefaultRequestObject.benlibrary_subjects = subj;
		mydefaultRequestObject.benlibrary_chapters = chap;
		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_srchtype = typ;
		mydefaultRequestObject.library_keywords = keywd;

		if(who == 'count') {
			mydefaultRequestObject.command = 'countDBListings';
			// console.log(mydefaultRequestObject);
			return $.ajax({type:'post',
				url: basicWebserviceURL,
				data: mydefaultRequestObject,
				timeout: 100000, //milliseconds
				success: function (data) {
					if (data.match(/WeBWorK error/)) {
						reportWWerror(data);		   
		       		}

					var response = $.parseJSON(data);
					// console.log(response);
					var arr = response.result_data;
					arr = arr[0];
					var line = maketext("There are") + " " + arr + " " + maketext("matching WeBWorK problems")
					if(arr == "1") {
						line = maketext("There is 1 matching WeBWorK problem")
					}
					$('#benlibrary_count_line').html(line);
					return true;
				},
				error: function (data) {
					alert('525 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
				},
			});
		}
		var subcommand = "getAllDBchapters";
		if(what == 'clear') {
			setselect('benlibrary_'+who, [all]);
			return benlib_update(child[who], 'clear');
		}
		if(who=='chapters' && subj=='') { return benlib_update(who, 'clear'); }
		if(who=='sections' && chap=='') { return benlib_update(who, 'clear'); }
		if(who=='sections') { subcommand = "getSectionListings";}
		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				// console.log(response);
				var arr = response.result_data;
				arr.splice(0,0,all);
				setselect('benlibrary_'+who, arr);
				benlib_update(child[who], 'clear');
				return true;
			},
			error: function (data) {
				alert('557 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function dir_update(who, what ) {
		var child = { lib : 'dir', dir : 'subdir', subdir : 'count'};
		var childe = { lib : 'libraries', dir : 'directories', subdir : 'subdirectories', count : ''};

		//nomsg();
		var all = 'All '+ capFirstLetter(childe[who]);
		all = maketext(all);

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}
		if(who == 'dir' && what == 'get') {
			$('[name="library_dir"]').prop("selectedIndex",0);
			$('[name="library_subdir"]').prop("selectedIndex",0);
		}
		if(who == 'subdir' && what == 'get') {
			$('[name="library_subdir"]').prop("selectedIndex",0);
		}
		var lib    = $('[name="library_lib"] option:selected').val();
		var dir    = $('[name="library_dir"] option:selected').val();
		var subdir = $('[name="library_subdir"] option:selected').val();

		var libind    = $('[name="library_lib"] option:selected').index();
		var dirind    = $('[name="library_dir"] option:selected').index();
		var subdirind = $('[name="library_subdir"] option:selected').index();
		var topdir = $('[name="library_topdir"]').val();

		if(libind == 0) { lib = '';};
		if(dirind == 0) { dir = '';};
		if(subdirind == 0) { subdir = '';};

		mydefaultRequestObject.library_topdir = topdir;
		mydefaultRequestObject.library_lib = lib;
		mydefaultRequestObject.library_dir = dir;
		mydefaultRequestObject.library_subdir = subdir;
		if(who == 'dir' && what == 'get' && $('[name="library_lib"] option:selected').index() > 0) {
			$("#lib_view_spcf").removeAttr("disabled");
		} else {
			if($('[name="library_lib"] option:selected').index() == 0) {
				$("#lib_view_spcf").attr("disabled","disabled");
			}
		}

		if(who == 'count') {
			mydefaultRequestObject.command = 'countDirListings';
			// console.log(mydefaultRequestObject);
			return $.ajax({type:'post',
				url: basicWebserviceURL,
				data: mydefaultRequestObject,
				timeout: 100000, //milliseconds
				success: function (data) {
					if (data.match(/WeBWorK error/)) {
						reportWWerror(data);		   
					}

					var response = $.parseJSON(data);
					//console.log(response);
					var arr = response.result_data;
					arr = arr[0];
					var line = maketext("There are") + " " + arr + " " + maketext("matching WeBWorK problems")
					if(arr == "1") {
						line = maketext("There is 1 matching WeBWorK problem")
					}
               			if($("select[name='library_lib'] option:selected").index() == 0) {
               				line = '';
               			}
					$('#slibrary_count_line').html(line);
					return true;
				},
				error: function (data) {
					alert('637 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
				},
			});

		}  
		if(what == 'clear') {
			setselect('library_'+who, [all]);
			return dir_update(child[who], 'clear');
		}

		if(who=='dir' && lib=='') { return dir_update(who, 'clear'); }
		if(who=='subdir' && dir=='') { return dir_update(who, 'clear'); }

		var subcommand = "getAllDirs";
		if(what == 'clear') {
			setselect('library_'+who, [all]);
			return dir_update(child[who], 'clear' );
		}
		if( who == 'dir' || who=='subdir') { subcommand = "getAllDirs";}
		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				//console.log(response);
				var arr = response.result_data;
				arr.splice(0,0,all);
				setselect('library_'+who, arr);
				dir_update(child[who], 'clear');
				return true;
			},
			error: function (data) {
				alert('676 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function lib_searchops() {

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}
		var subj = $('[name="blibrary_subjects"] option:selected').val();
		var chap = $('[name="blibrary_chapters"] option:selected').val();

		var subjind = $('[name="blibrary_subjects"] option:selected').index();
		var chapind = $('[name="blibrary_chapters"] option:selected').index();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		var keywd = $('[name="search_bpl"]').val();

		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_keywords = keywd;

		var subcommand = "getAllKeywords";

		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}
				var response = $.parseJSON(data);
				console.log(response);
				var arr = response.result_data;
				arr.splice(0,0);
				f_tags(arr);
               		return arr;
			},
			error: function (data) {
				alert('724 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function enlib_searchops() {

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}
		var subj = $('[name="benlibrary_subjects"] option:selected').val();
		var chap = $('[name="benlibrary_chapters"] option:selected').val();

		var subjind = $('[name="benlibrary_subjects"] option:selected').index();
		var chapind = $('[name="benlibrary_chapters"] option:selected').index();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		var keywd = $('[name="search_bplen"]').val();

		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.benlibrary_subjects = subj;
		mydefaultRequestObject.benlibrary_chapters = chap;
		mydefaultRequestObject.library_keywords = keywd;
		mydefaultRequestObject.library_srchtype = 'BPLEN';

		var subcommand = "getAllKeywords_en";

		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}
				var response = $.parseJSON(data);
				console.log(response);
				var arr = response.result_data;
				arr.splice(0,0);
				f_tagsen(arr);
               		return arr;
			},
			error: function (data) {
				alert('775 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function enkeywordclick(ar) {

		$(".keyworden").click( function() {
			kw = $(this).attr("keyworden");
        		var tags = $("input#search_bplen").val();

			$('input[name="search_bplen"]').tagsinput('add', kw);
			benlib_update('count', 'clear' );
			var ir = ar.indexOf(kw);
			if(ir > -1) 
				ar.splice(ir,1);
			return settop20keywordsen(ar);
		});
	}
	
	function keywordclick(ar) {

 		$(".keyword").click( function() {
			kw = $(this).attr("keyword");
			var tags = $("input#search_bpl").val();

			$('input[name="search_bpl"]').tagsinput('add', kw);
			blib_update('count', 'clear' );
			var ir = ar.indexOf(kw);
			if(ir > -1) 
				ar.splice(ir,1);
			return settop20keywords(ar);
		});
	}

	function enlib_top20keywords () {

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}
		var subj = $('[name="benlibrary_subjects"] option:selected').val();
		var chap = $('[name="benlibrary_chapters"] option:selected').val();
		var tags = $("input#search_bplen").val();
		var kwn  = $("input#library_defkeywordsen").val();

		var subjind = $('[name="benlibrary_subjects"] option:selected').index();
		var chapind = $('[name="benlibrary_chapters"] option:selected').index();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_keywords = tags;
		mydefaultRequestObject.library_defkeywords = kwn;
		
		var subcommand = "getTop20KeyWords_en";

		mydefaultRequestObject.command = subcommand;
		// console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}
				var response = $.parseJSON(data);
				console.log(response);
				var arr = response.result_data;
				arr.splice(0,0);
				settop20keywordsen(arr);
				return true;
			},
			error: function (data) {
				alert('854 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function lib_top20keywords () {

		var mydefaultRequestObject = init_webservice('searchLib');
		if(mydefaultRequestObject == null) {
			// We failed
			// console.log("Could not get webservice request object");
			return false;
		}
		var subj = $('[name="blibrary_subjects"] option:selected').val();
		var chap = $('[name="blibrary_chapters"] option:selected').val();
		var tags = $("input#search_bpl").val();
		var kwn  = $("input#library_defkeywords").val();

		var subjind = $('[name="blibrary_subjects"] option:selected').index();
		var chapind = $('[name="blibrary_chapters"] option:selected').index();

		if(subjind == 0) { subj = '';};
		if(chapind == 0) { chap = '';};

		mydefaultRequestObject.library_subjects = subj;
		mydefaultRequestObject.library_chapters = chap;
		mydefaultRequestObject.library_keywords = tags;
		mydefaultRequestObject.library_defkeywords = kwn;

		var subcommand = "getTop20KeyWords";

		mydefaultRequestObject.command = subcommand;
		console.log(mydefaultRequestObject);
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				console.log(response);
				var arr = response.result_data;
				arr.splice(0,0);
				settop20keywords(arr);
				return true;
			},
			error: function (data) {
				alert('905 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function settop20keywordsen(arr) {

		//Add the keywords to div kword
		var kwRows = '<div align="left" style="line-height: .8em;">';
		var arrayLength = arr.length;
		var tags = $("input#search_bplen").val();
		var tarr = tags.split(',');

		var wd = 0;
		for (var i = 0; i < arrayLength; i++)
		{
			// Do something
			//Check if arr[i] is already in tags
			if($.inArray(arr[i], tarr) > -1) {
				continue; 
			}
			wd += arr[i].length;
			kwRows += '<span id="keyworden" class="keyworden" keyworden="'+arr[i]+'" style="font-size: 13px; line-height: 200%;">'+arr[i]+'</span> ';
			if(wd > 100) { 
				kwRows += '<br />';
				wd = 0;
			}
		}
		kwRows += '</div>';
		document.getElementById("kworden").innerHTML = kwRows;
		enkeywordclick(arr);
		if(arrayLength < parseInt($("#library_defkeywordsen").val())) {
			$("#load_kwen").hide();
		} else {
			$("#load_kwen").show();
		}
	}

	function settop20keywords(arr) {

		//Add the keywords to div kword
		var kwRows = '<div align="left" style="line-height: .8em;">';
		var arrayLength = arr.length;
		var tags = $("input#search_bpl").val();
		var tarr = tags.split(',');
   
		var wd = 0;
		for (var i = 0; i < arrayLength; i++)
		{
			// Do something
			//Check if arr[i] is already in tags
			if($.inArray(arr[i], tarr) > -1) {
				continue; 
			}
			wd += arr[i].length;
			kwRows += '<span id="keyword" class="keyword" keyword="'+arr[i]+'" style="font-size: 13px; line-height: 200%;">'+arr[i]+'</span> ';
			if(wd > 100) { 
				kwRows += '<br />';
				wd = 0;
			}
       
		}
		kwRows += '</div>';
		document.getElementById("kword").innerHTML = kwRows;
		keywordclick(arr);
		if(arrayLength < parseInt($("#library_defkeywords").val())) {
			$("#load_kw").hide();
		} else {
			$("#load_kw").show();
		}
	}

	function setselect(selname, newarray) {
		var sel = $('[name="'+selname+'"]');
		sel.empty();
		$.each(newarray, function(i,val) {
			sel.append($("<option></option>").val(val).html(val));
		});
	}

	function capFirstLetter(string) {
		return string.charAt(0).toUpperCase() + string.slice(1);
	}

	function addme(path, who) {
		nomsg();
		var selectsetstring = maketext("Select a Set from this Course");
		var target = $('[name="local_sets"] option:selected').val();
		if(target == selectsetstring) {
			alert(maketext("You need to pick a target set above so we know what set to which we should add this problem."));
			return true;
		}
		var mydefaultRequestObject = init_webservice('addProblem');
		if(mydefaultRequestObject == null) {
			// We failed
			badmsg("Could not connect back to server");
			return false;
		}
		mydefaultRequestObject.set_id = target;
		var pathlist = new Array();
		if(who=='one') {
			pathlist.push(path);
		} else { // who == 'all'
			var allprobs = $('[name^="filetrial"]');
			for(var i=0,len =allprobs.length; i< len; ++i) {
				pathlist.push(allprobs[i].value);
			}
		}
		mydefaultRequestObject.total = pathlist.length;
		mydefaultRequestObject.set = target;
		addemcallback(basicWebserviceURL, mydefaultRequestObject, pathlist, 0)(true);
	}

	function addemcallback(wsURL, ro, probarray, count) {
		if(probarray.length==0) {
			return function(data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				//var phrase = count+" problem";
				//if(count!=1) { phrase += "s";}
				// alert("Added "+phrase+" to "+ro.set);
				markinset();

				var prbs = pluralise("problem","problems",count);
				//if(ro.total == 1) { 
				//   prbs = "problem";
				//}
				goodmsg(maketext("Added") + " "+ro.total+" "+prbs+" " + maketext("to set")+" "+ro.set_id);

				return true;
			};
		}
		// Need to clone the object so the recursion works
		var ro2 = jQuery.extend(true, {}, ro);
		ro2.problemPath=probarray.shift();
		return function (data) {
			return $.ajax({type:'post',
				url: wsURL,
				data: ro2,
				timeout: 100000, //milliseconds
				success: addemcallback(wsURL, ro2, probarray, count+1),
				error: function (data) {
					alert('1088 setmaker.js: '+wsURL+': '+data.statusText);
				},
			});

		};
	}

	// Reset all the messages about who is in the current set
	function markinset() {
		var ro = init_webservice('listSetProblems');
		var target = $('[name="local_sets"] option:selected').val();
		if(target == 'Select a Set from this Course') {
			target = null;
		}
		var shownprobs = $('[name^="filetrial"]'); // shownprobs.value
		ro.set_id = target;
		ro.command = 'true';
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: ro,
			timeout: 100000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				// console.log(response);
				var arr = response.result_data;
				var pathhash = {};
				for(var i=0; i<arr.length; i++) {
					arr[i] = arr[i].path;
					arr[i] = arr[i].replace(/^\//,'');
					pathhash[arr[i]] = 1;
				}
				for(var i=0; i< shownprobs.length; i++) {
					var num= shownprobs[i].name;
					num = num.replace("filetrial","");
					if(pathhash[shownprobs[i].value] ==1) {
						$('#inset'+num).html('<i><b>(' + maketext("in target set") + ')</b></i>');
					} else {
						$('#inset'+num).html('<i><b></b></i>');
					}
				}
			},
			error: function (data) {
				alert('1094 setmaker.js: '+ basicWebserviceURL+': '+data.statusText);
			},
		});
	}

	function delrow(num) { 
		nomsg();
		var path = $('[name="filetrial'+ num +'"]').val();
		var APLindex = findAPLindex(path);
		var mymlt = $('[name="all_past_mlt'+ APLindex +'"]').val();
		var cnt = 1;
		var loop = 1;
		var mymltM = $('#mlt'+num);
		var mymltMtext = 'L'; // so extra stuff is not deleted
		if(mymltM) {
			mymltMtext = mymltM.text();
		}
		$('#pgrow'+num).remove(); 
		delFromPGList(num, path);
		if((mymlt > 0) && mymltMtext=='M') { // delete hidden problems
			var table_num = num;
			while((newmlt = $('[name="all_past_mlt'+ APLindex +'"]')) && newmlt.val() == mymlt) {
				cnt += 1;
				num++;
				path = $('[name="filetrial'+ num +'"]').val();
				$('#pgrow'+num).remove(); 
				delFromPGList(num, path);
			}
			$('#mlt-table'+table_num).remove();
		} else if ((mymlt > 0) && $('.MLT'+mymlt).length == 0) {
			$('#mlt-table'+num).remove();
		} else if ((mymlt > 0) && mymltMtext=='L') {
			var new_num = $('#mlt-table'+num+' .MLT'+mymlt+':first')
				.attr('id').match(/pgrow([0-9]+)/)[1];
			$('#mlt-table'+num).attr('id','mlt-table'+new_num);
			var onclickfunction = mymltM.attr('onclick').replace(num,new_num);
			mymltM.attr('id','mlt'+new_num).attr('onclick', onclickfunction);
			var insetel = $('#inset'+new_num);
			insetel.next().after(mymltM).after(" ");
			var classstr = $('#pgrow'+new_num).attr('class')
				.replace('MLT'+mymlt,'NS'+new_num);
			$('#pgrow'+new_num).attr('class',classstr);
		}
		// Update various variables in the page
		var n1 = $('#lastshown').text();
		var n2 = $('#totalshown').text();
		$('#lastshown').text(n1-1);
		$('#totalshown').text(n2-1);
		var lastind = $('[name="last_index"]');
		lastind.val(lastind.val()-cnt);
		var ls = $('[name="last_shown"]').val();
		ls--;
		$('[name="last_shown"]').val(ls);
		if(ls < $('[name="first_shown"]').val()) {
			$('#what_shown').text('None');
		}
		//  showpglist();
		return(true);
	}

	function findAPLindex(path) {
		var j=0;
		while ($('[name="all_past_list'+ j +'"]').val() != path && (j<1000)) {
			j++;
		}
		if(j==1000) { alert('1159 setmaker.js: ' + "Cannot find " +path);}
		return j;
	}

	function delFromPGList(num, path) {
		var j = findAPLindex(path);
		j++;
		while ($('[name="all_past_list'+ j +'"]').length>0) {
			var jm = j-1;
			$('[name="all_past_list'+ jm +'"]').val($('[name="all_past_list'+ j +'"]').val());
			$('[name="all_past_mlt'+ jm +'"]').val($('[name="all_past_mlt'+ j +'"]').val());
			j++;
		}
		j--;
		// var v = $('[name="all_past_list'+ j +'"]').val();
		$('[name="all_past_list'+ j +'"]').remove();
		$('[name="all_past_mlt'+ j +'"]').remove();
		return true;
	}

	var language = $('#hidden_language').val();
	var basicRendererURL = "/webwork2/html2xml?&language=" + language;

	async function render(id) {
		return new Promise(function(resolve, reject) {
			var renderArea = $('#psr_render_area_' + id);

			var iframe = renderArea.find('#psr_render_iframe_' + id);
			if (iframe[0] && iframe[0].iFrameResizer) {
				iframe[0].contentDocument.location.replace('about:blank');
			}

			var ro = {
				userID: $('#hidden_user').val(),
				courseID: $('#hidden_courseID').val(),
				session_key: $('#hidden_key').val()
			};

			if (!(ro.userID && ro.courseID && ro.session_key)) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text("Missing hidden credentials: user, session_key, courseID"));
				resolve();
				return;
			}

			ro.sourceFilePath = renderArea.data('pg-file');
			ro.outputformat = 'simple';
			ro.showAnswerNumbers = 0;
			ro.problemSeed = Math.floor((Math.random()*10000));
			ro.showHints = $('input[name=showHints]').is(':checked') ? 1 : 0;
			ro.showSolutions = $('input[name=showSolutions]').is(':checked') ? 1 : 0;
			ro.noprepostambles = 1;
			ro.processAnswers = 0;
			ro.showFooter = 0;
			ro.displayMode = $('select[name=mydisplayMode]').val();
			ro.send_pg_flags = 1;
			ro.extra_header_text = "<style>html{overflow-y:hidden;}body{padding:0;background:#f5f5f5;.container-fluid{padding:0px;}</style>";
			if (window.location.port) ro.forcePortNumber = window.location.port;

			$.ajax({type:'post',
				url: basicRendererURL,
				data: ro,
				dataType: "json",
				timeout: 10000, //milliseconds
			}).done(function (data) {
				// Give nicer session timeout error
				if (!data.html || /Can\'t authenticate -- session may have timed out/i.test(data.html) ||
					/Webservice.pm: Error when trying to authenticate./i.test(data.html)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text("Can't authenticate -- session may have timed out."));
					resolve();
					return;
				}
				// Give nicer file not found error
				if (/this problem file was empty/i.test(data.html)) {
					renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('No Such File or Directory!'));
					resolve();
					return;
				}
				// Give nicer problem rendering error
				if ((data.pg_flags && data.pg_flags.error_flag) ||
					/error caught by translator while processing problem/i.test(data.html) ||
					/error message for command: renderproblem/i.test(data.html)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('There was an error rendering this problem!'));
					resolve();
					return;
				}

				if (!(iframe[0] && iframe[0].iFrameResizer)) {
					iframe = $("<iframe/>", { id: "psr_render_iframe_" + id });
					iframe[0].style.border = 'none';
					renderArea.html(iframe);
					if (data.pg_flags && data.pg_flags.comment) iframe.after($(data.pg_flags.comment));
					iFrameResize({ checkOrigin: false, warningTimeout: 20000, scrolling: 'omit' }, iframe[0]);
					iframe[0].addEventListener('load', function() { resolve(); });
				}
				iframe[0].srcdoc = data.html;
			}).fail(function (data) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text(basicRendererURL + ': ' + data.statusText));
				resolve();
			});
		});
	}

	async function togglemlt(cnt, noshowclass) {
		nomsg();
		let unshownAreas = $('.' + noshowclass);
		var count = unshownAreas.length;
		var n1 = $('#lastshown').text();
		var n2 = $('#totalshown').text();

		if($('#mlt' + cnt).text() == 'M') {
			unshownAreas.show();
			// Render any problems that were hidden that have not yet been rendered.
			for (let area of unshownAreas) {
				let iframe = $(area).find('iframe[id^=psr_render_iframe_]');
				if (iframe[0] && iframe[0].iFrameResizer) iframe[0].iFrameResizer.resize();
				else await render(area.id.match(/^pgrow(\d+)/)[1]);
			}
			$('#mlt' + cnt).text("L");
			$('#mlt' + cnt).attr("title", "Show less like this");
			count = -count;
		} else {
			unshownAreas.hide();
			$('#mlt' + cnt).text("M");
			$('#mlt' + cnt).attr("title", "Show " + unshownAreas.length + " more like this");
		}
		$('#lastshown').text(n1 - count);
		$('#totalshown').text(n2 - count);
		$('[name="last_shown"]').val($('[name="last_shown"]').val() - count);
	}

	function showpglist() {
		var j=0;
		var s='';
		while ($('[name="all_past_list'+ j +'"]').length>0) {
			s = s+ $('[name="all_past_list'+ j +'"]').val()+", "+ $('[name="all_past_mlt'+ j +'"]').val()+"\n";
			j++;
		}
		alert(s);
		return true;
	}

	function reportWWerror(data) {
		console.log(data);
		$('<div/>',{class : 'WWerror', title : 'WeBWorK Error'})
			.html(data)
			.dialog({width:'70%'});
	}

	// Set up the problem rerandomization buttons.
	$(".rerandomize_problem_button").click(function() {
		var targetProblem = $(this).data('target-problem');
		render(targetProblem);
	});

	// Find all render areas
	var renderAreas = $('.psr_render_area');

	// Add the loading message to all render areas.
	for (var renderArea of renderAreas) {
		$(renderArea).html(maketext('Loading Please Wait...'));
	}

	// Render all visible problems on the page
	(async function() {
		for (let renderArea of renderAreas) {
			if (!$(renderArea).is(':visible')) continue;
			await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
		}
	})();

	$("select[name=library_chapters]").on("change", function() { lib_update('sections', 'get'); });
	$("select[name=library_subjects]").on("change", function() { lib_update('chapters', 'get'); });
	$("select[name=library_sections]").on("change", function() { lib_update('count', 'clear'); });
	$("input[name=level]").on("change", function() { lib_update('count', 'clear'); });
	$("input[name=select_all]").click(function() { addme('', 'all'); });
	$("input[name=add_me]").click(function() { addme($(this).data('source-file'), 'one'); });
	$("select[name=local_sets]").on("change", markinset);
	$("span[name=dont_show]").click(function() { delrow($(this).data('row-cnt')); });
	$(".lb-mlt-parent").click(function() { togglemlt($(this).data('mlt-cnt'), $(this).data('mlt-noshow-class')); });
	$("select[name=library_lib]").on("change", function() { dir_update('dir', 'get'); });
	$("select[name=library_dir]").on("change", function() { dir_update('subdir', 'get'); });
	$("select[name=library_subdir]").on("change", function() { dir_update('count', 'clear'); });
	
	$("input[name=lib_view_bpl]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=lib_view_bplen]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=lib_view]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=view_local_set]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=view_mysets_set]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=view_setdef_set]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
	$("input[name=lib_view_spcf]").click(function() { setBrowseWhich($('[name="lib_deftab"]').val()); });
})();
