################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################


package WeBWorK::ContentGenerator::Instructor::SetMaker;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetMaker - Make homework sets.

=cut

use strict;
use warnings;


#use CGI qw(-nosticky);
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::Utils qw(readDirectory max sortByName wwRound x);
use WeBWorK::Utils::Tasks qw(renderProblems);
use WeBWorK::Utils::Tags;
use WeBWorK::Utils::LibraryStats;
use WeBWorK::Utils::LanguageAndDirection;
use File::Find;
use MIME::Base64 qw(encode_base64);
use Encode;

require WeBWorK::Utils::ListingDB;

# we use x to mark strings for maketext
use constant SHOW_HINTS_DEFAULT => 0;
use constant DEFAULT_KEYWORDS => 20;
use constant SHOW_SOLUTIONS_DEFAULT => 0;
use constant MAX_SHOW_DEFAULT => 20;
use constant NO_LOCAL_SET_STRING => x('No sets in this course yet');
use constant SELECT_SET_STRING => x('Select a Set from this Course');
use constant SELECT_LOCAL_STRING => x('Select a Problem Collection');
use constant SELECT_HMW_SET_STRING => x('Select a Homework Set');
use constant SELECT_SETDEF_FILE_STRING => x('Select a Set Definition File');
use constant MY_PROBLEMS => x('My Problems');
use constant MAIN_PROBLEMS => x('Unclassified Problems');
use constant ALL_CHAPTERS => 'All Chapters';
use constant ALL_SUBJECTS => 'All Subjects';
use constant ALL_SECTIONS => 'All Sections';
use constant ALL_TEXTBOOKS => 'All Textbooks';
use constant ALL_LIBS => 'Select Library';
use constant ALL_DIRS => 'All Directories';
use constant ALL_SUBDIRS => 'All Subdirectories';
use constant VIEW_FORMS  => [ qw(frenchProblemLibrary englishProblemLibrary openProblemLibrary localProblems fromThisCourse setDefinitionFiles specificDirectories)];
use constant ACTION_FORMS  => {frenchProblemLibrary  => 'browse_library_panel5t',englishProblemLibrary  => 'browse_library_panel5ten', openProblemLibrary => 'browse_library_panel2t', localProblems => 'browse_local_panelt', fromThisCourse => 'browse_mysets_panelt', setDefinitionFiles => 'browse_setdef_panelt', specificDirectories => 'browse_specific_panelt'};
use constant FORMS_TAB  => {'browse_bpl_library' => 0,'browse_bplen_library' => 1, 'browse_npl_library' => 2, 'browse_local' => 3, 'browse_mysets' => 4, 'browse_setdefs' => 5, 'browse_spcf_library' => 6};

use constant LIB2_DATA => {
  'dbchapter' => {name => 'library_chapters', all => 'All Chapters'},
  'dbsection' =>  {name => 'library_sections', all =>'All Sections' },
  'dbsubject' =>  {name => 'library_subjects', all => 'All Subjects' },
  'textbook' =>  {name => 'library_textbook', all =>  'All Textbooks'},
  'textchapter' => {name => 'library_textchapter', all => 'All Chapters'},
  'textsection' => {name => 'library_textsection', all => 'All Sections'},
  'keywords' =>  {name => 'library_keywords', all => '' },
  };

## Flags for operations on files

use constant ADDED => 1;
use constant HIDDEN => (1 << 1);
use constant SUCCESS => (1 << 2);

##	for additional problib buttons
my %problib;	## This is configured in defaults.config
my %ignoredir = (
	'.' => 1, '..' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, 'graphics'=>1, '.svn' => 1, 'achievements' => 1,
);

sub prepare_activity_entry {
	my $self=shift;
	my $r = $self->r;
	my $user = $self->r->param('user') || 'NO_USER';
	return("In SetMaker as user $user");
}

## This is for searching the disk for directories containing pg files.
## to make the recursion work, this returns an array where the first 
## item is the number of pg files in the directory.  The second is a
## list of directories which contain pg files.
##
## If a directory contains only one pg file and the directory name
## is the same as the file name, then the directory is considered
## to be part of the parent directory (it is probably in a separate
## directory only because it has auxiliary files that want to be
## kept together with the pg file).
##
## If a directory has a file named "=library-ignore", it is never
## included in the directory menu.  If a directory contains a file
## called "=library-combine-up", then its pg are included with those
## in the parent directory (and the directory does not appear in the
## menu).  If it has a file called "=library-no-combine" then it is
## always listed as a separate directory even if it contains only one
## pg file.

sub get_library_sets {
	my $top = shift; my $dir = shift;
	# ignore directories that give us an error
	my @lis = eval { readDirectory($dir) };
	if ($@) {
		warn $@;
		return (0);
	}
	return (0) if grep /^=library-ignore$/, @lis;

	my @pgfiles = grep { m/\.pg$/ and (not m/(Header|-text)(File)?\.pg$/) and -f "$dir/$_"} @lis;
	my $pgcount = scalar(@pgfiles);
	my $pgname = $dir; $pgname =~ s!.*/!!; $pgname .= '.pg';
	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep /^=library-no-combine$/, @lis));

	my @pgdirs;
	my @dirs = grep {!$ignoredir{$_} and -d "$dir/$_"} @lis;
	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
	# Never include Library at the top level
	if ($top == 1) {@dirs = grep {$_ ne 'Library'} @dirs} 
	foreach my $subdir (@dirs) {
		my @results = get_library_sets(0, "$dir/$subdir");
		$pgcount += shift @results; push(@pgdirs,@results);
	}

	return ($pgcount, @pgdirs) if $top || $combineUp || grep /^=library-combine-up$/, @lis;
	return (0,@pgdirs,$dir);
}

sub get_library_pgs {
	my $top = shift; my $base = shift; my $dir = shift;
	my @lis = readDirectory("$base/$dir");
	return () if grep /^=library-ignore$/, @lis;
	return () if !$top && grep /^=library-no-combine$/, @lis;

	my @pgs = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$base/$dir/$_"} @lis;
	my $others = scalar(grep { (!m/\.pg$/ || m/(Header|-text)\.pg$/) &&
	                            !m/(\.(tmp|bak)|~)$/ && -f "$base/$dir/$_" } @lis);

	my @dirs = grep {!$ignoredir{$_} and -d "$base/$dir/$_"} @lis;
	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
	foreach my $subdir (@dirs) {push(@pgs, get_library_pgs(0,"$base/$dir",$subdir))}

	return () unless $top || (scalar(@pgs) == 1 && $others) || grep /^=library-combine-up$/, @lis;
	return (map {"$dir/$_"} @pgs);
}

sub list_pg_files {
	my ($templates,$dir) = @_;
	my $top = ($dir eq '.')? 1 : 2;
	my @pgs = get_library_pgs($top,$templates,$dir);
	return sortByName(undef,@pgs);
}
sub get_sub_reps {
	my $topdir = shift;
	my @found_set_defs;
   
        opendir(my $dh, $topdir) || print STDERR "Can't opendir $topdir: $!";
        while(readdir $dh) {
            next if /^\.+/;
            if(-d "$topdir/$_") {
               push @found_set_defs, $_ ;
            }
        }

	#find({ wanted => $get_set_defs_wanted, follow_fast=>1, no_chdir=>1 , bydepth => 0}, $topdir);
	#map { $_ =~ s|^$topdir/?|| } @found_set_defs;
	return @found_set_defs;

}

## Search for set definition files

sub get_set_defs {
	my $topdir = shift;
	my @found_set_defs;
	# get_set_defs_wanted is a closure over @found_set_defs
	my $get_set_defs_wanted = sub {
		#my $fn = $_;
		#my $fdir = $File::Find::dir;
		#return() if($fn !~ /^set.*\.def$/);
		##return() if(not -T $fn);
		#push @found_set_defs, "$fdir/$fn";
		push @found_set_defs, $_ if m|/set[^/]*\.def$|;
	};
	find({ wanted => $get_set_defs_wanted, follow_fast=>1, no_chdir=>1}, $topdir);
	map { $_ =~ s|^$topdir/?|| } @found_set_defs;
	return @found_set_defs;
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path {
	my $self = shift;
	my $pg_path = shift;
	my $path_to_set_def = shift;
	my $end_path = $pg_path;
	# if the path is ok, don't fix it
	return($pg_path) if(-e $self->r->ce->{courseDirs}{templates}."/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return($end_path) if(-e $self->r->ce->{courseDirs}{templates}."/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return($pg_path);
}

## Problems straight from the OPL database come with MO and static
## tag information.  This is for other times, like next/prev page.

sub getDBextras {
	my $r = shift;
	my $sourceFileName = shift;

	if($sourceFileName =~ /^Library/) {
		return @{WeBWorK::Utils::ListingDB::getDBextras($r, $sourceFileName)};
	}

	my $filePath = $r->ce->{courseDirs}{templates}."/$sourceFileName";
	my $tag_obj = WeBWorK::Utils::Tags->new($filePath);
	my $isMO = $tag_obj->{MO} || 0;
	my $isstatic = $tag_obj->{Static} || 0;

	return ($isMO, $isstatic);
}

## With MLT, problems come in groups, so we need to find next/prev
## problems.  Return index, or -1 if there are no more.
sub next_prob_group {
	my $ind = shift;
	my @pgfiles = @_;
	my $len = scalar(@pgfiles);
	return -1 if($ind >= $len-1);
	my $mlt= $pgfiles[$ind]->{morelt} || 0;
	return $ind+1 if($mlt == 0);
	while($ind<$len and defined($pgfiles[$ind]->{morelt}) and $pgfiles[$ind]->{morelt} == $mlt) {
		$ind++;
	}
	return -1 if($ind==$len);
	return $ind;
}

sub prev_prob_group {
	my $ind = shift;
	my @pgfiles = @_;
	return -1 if $ind==0;
	$ind--;
	my $mlt = $pgfiles[$ind]->{morelt};
	return $ind if $mlt==0;
	# We have to search to the beginning of this group
	while($ind>=0 and $mlt == $pgfiles[$ind]->{morelt}) {
		$ind--;
	}
	return($ind+1);
}

sub end_prob_group {
	my $ind = shift;
	my @pgfiles = @_;
	my $next = next_prob_group($ind, @pgfiles);
	return( ($next==-1) ? $#pgfiles : $next-1);
}

## Read a set definition file.  This could be abstracted since it happens
## elsewhere.  Here we don't have to process so much of the file.

sub read_set_def {
	my $self = shift;
	my $r = $self->r;
	my $filePathOrig = shift;
	my $filePath = $r->ce->{courseDirs}{templates}."/$filePathOrig";
	$filePathOrig =~ s/set.*\.def$//;
	$filePathOrig =~ s|/$||;
	$filePathOrig = "." if ($filePathOrig !~ /\S/);
	my @pg_files = ();
	my ($line, $got_to_pgs, $name, @rest) = ("", 0, "");
	if ( open (SETFILENAME, "$filePath") )    {
	    while($line = <SETFILENAME>) {
		chomp($line);
		$line =~ s|(#.*)||; # don't read past comments
		if($got_to_pgs == 1) {
		    unless ($line =~ /\S/) {next;} # skip blank lines
		    ($name,@rest) = split (/\s*,\s*/,$line);
		    $name =~ s/\s*//g;
		    push @pg_files, $name;
		} elsif ($got_to_pgs == 2) {
		    # skip lines which dont identify source files
		    unless ($line =~ /source_file\s*=\s*(\S+)/) {
			next;
		    }
		    # otherwise we got the name from the regexp
		    push @pg_files, $1;
		} else {
		    $got_to_pgs = 1 if ($line =~ /problemList\s*=/);
		    $got_to_pgs = 2 if ($line =~ /problemListV2/);
		}
	    }
	} else {
	    $self->addbadmessage($r->maketext("Cannot open [_1]",$filePath));
	}
	# This is where we would potentially munge the pg file paths
	# One possibility
	@pg_files = map { $self->munge_pg_file_path($_, $filePathOrig) } @pg_files;
	return(@pg_files);
}

## go through past page getting a list of identifiers for the problems
## and whether or not they are selected, and whether or not they should
## be hidden

sub get_past_problem_files {
	my $r = shift;
	my @found=();
	my $count =1;
	while (defined($r->param("filetrial$count"))) {
		my $val = 0;
		$val |= ADDED if($r->param("trial$count"));
		$val |= HIDDEN if($r->param("hideme$count"));
		push @found, [$r->param("filetrial$count"), $val];			
		$count++;
	}
	return(\@found);
}

#### For adding new problems

sub add_selected {
	my $self = shift;
	my $db = shift;
	my $setName = shift;
	my @past_problems = @{$self->{past_problems}};
	my @selected = @past_problems;
	my (@path, $file, $selected, $freeProblemID);
	# DBFIXME count would work just as well
	my $addedcount=0;

	for $selected (@selected) {
		if($selected->[1] & ADDED) {
			$file = $selected->[0];
			my $problemRecord = $self->addProblemToSet(setName => $setName,
				sourceFile => $file);
			$freeProblemID++;
			$self->assignProblemToAllSetUsers($problemRecord);
			$selected->[1] |= SUCCESS;
			$addedcount++;
		}
	}
	return($addedcount);
}


############# List of sets of problems in templates directory

sub get_problem_directories {
        my $r = shift;
        my $ce = $r->ce;
	my $lib = shift;
	my $source = $ce->{courseDirs}{templates};
	my $main = $r->maketext(MY_PROBLEMS); my $isTop = 1;
	if ($lib) {$source .= "/$lib"; $main = $r->maketext(MAIN_PROBLEMS); $isTop = 2}
	my @all_problem_directories = get_library_sets($isTop, $source);
	my $includetop = shift @all_problem_directories;
	my $j;
	for ($j=0; $j<scalar(@all_problem_directories); $j++) {
		$all_problem_directories[$j] =~ s|^$ce->{courseDirs}->{templates}/?||;
	}
	@all_problem_directories = sortByName(undef, @all_problem_directories);
	unshift @all_problem_directories, $main if($includetop);
	return (\@all_problem_directories);
}

############# Everyone has a view problems line.	Abstract it
sub view_problems_line {
	my $internal_name = shift;
	my $label = shift;
	my $r = shift; # so we can get parameter values
        my $t = shift;
	my $result = CGI::submit(-name=>"$internal_name",-id=>"$internal_name", -value=>$label);
	$result .= CGI::reset(-id=>"reset",-name=>"reset", -value=> $r->maketext('Reset'));

	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
		@{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	# We have our own displayMode since its value may be None, which is illegal
	# in other modules.
	my $mydisplayMode = $r->param('mydisplayMode') || $r->ce->{pg}->{options}->{displayMode};
	$result .= ' '.$r->maketext('Display Mode:').' '.CGI::popup_menu(-name=> 'mydisplayMode',
	                                                            -values=>\@active_modes,
	                                                            -default=> $mydisplayMode);
	#$result .= '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.$r->maketext('Display Mode:').' '.CGI::popup_menu(-name=> 'mydisplayMode',
	#                                                            -values=>\@active_modes,
	#                                                            -default=> $mydisplayMode);
	# Now we give a choice of the number of problems to show
	#my $defaultMax = $r->param('max_shown') || MAX_SHOW_DEFAULT;
	#$result .= ' '.$r->maketext('Max. Shown:').' '.
	#	CGI::popup_menu(-name=> 'max_shown',
	#	                -values=>[5,10,15,20,25,30,50,$r->maketext("All")],
	#	                -default=> $defaultMax);
	# Option of whether to show hints and solutions
	my $defaultHints = $r->param('showHints') || SHOW_HINTS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showHints",-id=>"showHints",-checked=>$defaultHints,-label=>$r->maketext("Hints"));
	my $defaultSolutions = $r->param('showSolutions') || SHOW_SOLUTIONS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showSolutions",-id=>"showSolutions", -checked=>$defaultSolutions,-label=>$r->maketext("Solutions"));
	$result .= "\n".CGI::hidden(-name=>"original_displayMode", -default=>$mydisplayMode)."\n";
	
	return($result);
}

sub view_problems_line_bpl {
	my $internal_name = shift;
	my $label = shift;
        my $count_line = shift;
	my $r = shift; # so we can get parameter values
        my $j = 0;
        $j = 1 if($internal_name eq "lib_view_bplen");
        $j = 6 if($internal_name eq "lib_view_spcf");
	my $result = CGI::submit(-name=>"$internal_name",-id=>"$internal_name", -value=>$label);
        $result .= CGI::reset(-id=>"reset",-name=>"reset", -value=> $r->maketext('Reset'));

	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
		@{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	# We have our own displayMode since its value may be None, which is illegal
	# in other modules.
	my $mydisplayMode = $r->param('mydisplayMode') || $r->ce->{pg}->{options}->{displayMode};
	#$result .= '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.$r->maketext('Display Mode:').' '.CGI::popup_menu(-name=> 'mydisplayMode',
	#                                                            -values=>\@active_modes,
	#                                                            -default=> $mydisplayMode);
	$result .= ' '.$r->maketext('Display Mode:').' '.CGI::popup_menu(-name=> 'mydisplayMode',
									   -values=>\@active_modes,
									   -default=> $mydisplayMode);

	#$result .= "\n".CGI::hidden(-name=>"showSolutions", -default=>1)."\n";
	#$result .= "\n".CGI::hidden(-name=>"showHints", -default=>1)."\n";

	my $defaultHints = $r->param('showHints') || SHOW_HINTS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showHints",-checked=>$defaultHints,-label=>$r->maketext("Hints"));
	my $defaultSolutions = $r->param('showSolutions') || SHOW_SOLUTIONS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showSolutions",-checked=>$defaultSolutions,-label=>$r->maketext("Solutions"));
	$result .= "\n".CGI::hidden(-name=>"original_displayMode", -default=>$mydisplayMode)."\n";


=comment
	# Now we give a choice of the number of problems to show
	my $defaultMax = $r->param('max_shown') || MAX_SHOW_DEFAULT;
	$result .= ' '.$r->maketext('Max. Shown:').' '.
		CGI::popup_menu(-name=> 'max_shown',
		                -values=>[5,10,15,20,25,30,50,$r->maketext("All")],
		                -default=> $defaultMax);
=cut
	return($result);
}

### The browsing panel has three versions
#####	 Version 1 is local problems
sub browse_local_panel {
	my $self = shift;
	my $r = $self->r;	
	my $library_selected = shift;
	my $lib = shift || ''; $lib =~ s/^browse_//;
	my $name = ($lib eq '')? $r->maketext('Local') : Encode::decode("UTF-8",$problib{$lib});
    
	my $list_of_prob_dirs= get_problem_directories($r,$lib);
	if(scalar(@$list_of_prob_dirs) == 0) {
		$library_selected = $r->maketext("Found no directories containing problems");
		unshift @{$list_of_prob_dirs}, $library_selected;
	} else {
		my $default_value = $r->maketext(SELECT_LOCAL_STRING);
		if (not $library_selected or $library_selected eq $default_value) {
			unshift @{$list_of_prob_dirs},	$default_value;
			$library_selected = $default_value;
		}
	}
	debug("library is $lib and sets are $library_selected");
	my $view_problem_line = view_problems_line('view_local_set', $r->maketext('View Problems'), $self->r);
	my @popup_menu_args = (
		-name => 'library_sets',
		-values => $list_of_prob_dirs,
		-default => $library_selected,
	);
	# make labels without the $lib prefix -- reduces the width of the popup menu
	if (length($lib)) {
		my %labels = map { my($l)=$_=~/^$lib\/(.*)$/;$_=>$l } @$list_of_prob_dirs;
		push @popup_menu_args, -labels => \%labels;
	}
	print CGI::Tr({}, CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("[_1] Problems", $name).' ',
		              CGI::popup_menu(@popup_menu_args),
		              CGI::br(), 
		              $view_problem_line,
	));
}

sub browse_local_panelt {
	my $self = shift;
	my $r = $self->r;	
	#my $library_selected = $self->{llibrary_set};
	my $library_selected = $self->{current_library_set};
	my $lib = shift || ''; $lib =~ s/^browse_//;
	my $name = ($lib eq '')? $r->maketext('Local') : Encode::decode_utf8($problib{$lib});
    
	my $list_of_prob_dirs= get_problem_directories($r,$lib);

	my $default_value = $r->maketext(SELECT_LOCAL_STRING);
	unshift @{$list_of_prob_dirs},	$default_value;

	if(scalar(@$list_of_prob_dirs) == 0) {
		$library_selected = $r->maketext("Found no directories containing problems");
		unshift @{$list_of_prob_dirs}, $library_selected;
	} else {
		if (not $library_selected or $library_selected eq $default_value) {
			#unshift @{$list_of_prob_dirs},	$default_value;
			$library_selected = $default_value;
		}
	}
	debug("library is $lib and sets are $library_selected");
	my $view_problem_line = view_problems_line('view_local_set', $r->maketext('View Problems'), $self->r, 3);
	my @popup_menu_args = (
		-name => 'llibrary_sets',
		-values => $list_of_prob_dirs,
		-default => $library_selected,
	);
	# make labels without the $lib prefix -- reduces the width of the popup menu
	if (length($lib)) {
		my %labels = map { my($l)=$_=~/^$lib\/(.*)$/;$_=>$l } @$list_of_prob_dirs;
		push @popup_menu_args, -labels => \%labels;
	}

	return   CGI::start_table({-width=>"80%",-align=>"left"}).
                 CGI::Tr({}, CGI::td({-class=>"InfoPanel", -align=>"left"}, [$r->maketext("Browse from").' ',
		              CGI::popup_menu(@popup_menu_args)])).
               CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left",-colspan=>"2"},"&nbsp;")).
                 CGI::Tr({}, CGI::td({-class=>"InfoPanel", -align=>"left",colspan=>"2"}, $view_problem_line
	            )).
                 CGI::end_table();
}

#####	 Version 2 is local homework sets
sub browse_mysets_panel {
	my $self = shift;
	my $r = $self->r;	
	my $library_selected = shift;
	my $list_of_local_sets = shift;
	my $default_value = $r->maketext(SELECT_HMW_SET_STRING);

	if(scalar(@$list_of_local_sets) == 0) {
		$list_of_local_sets = [$r->maketext(NO_LOCAL_SET_STRING)];
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		unshift @{$list_of_local_sets},	 $default_value; 
		$library_selected = $default_value; 
	} 

	my $view_problem_line = view_problems_line('view_mysets_set', $r->maketext('View Problems'), $self->r);
	print   CGI::start_table(),
                CGI::Tr({},
		CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("Browse from").' ',
		CGI::popup_menu(-name=> 'library_sets', 
		                -values=>$list_of_local_sets, 
		                -default=> $library_selected),
		CGI::br(), 
		$view_problem_line
	)),
                CGI::end_table();
}

sub browse_mysets_panelt {
	my $self = shift;
	my $r = $self->r;	
	#my $library_selected = shift;
        my $set_selected = $r->param('local_sets');
        my $library_selected = $self->{current_library_set};
	#my $list_of_local_sets = shift;
	my $list_of_local_sets = $self->{all_db_sets};

	my $default_value = $r->maketext(SELECT_HMW_SET_STRING);
	unshift @{$list_of_local_sets},	 $default_value; 

	if(scalar(@$list_of_local_sets) == 0) {
		$list_of_local_sets = [$r->maketext(NO_LOCAL_SET_STRING)];
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		$library_selected = $default_value; 
	} 

	my $view_problem_line = view_problems_line('view_mysets_set', $r->maketext('View Problems'), $self->r, 4 );
	return CGI::start_table({-align=>"left",width=>"80%"}),
               CGI::Tr({},
		CGI::td({-class=>"InfoPanel", -align=>"left"}, [$r->maketext("Browse from").' ',
		CGI::popup_menu(-name=> 'mlibrary_sets', 
		                -values=>$list_of_local_sets, 
		                -default=> $library_selected)]
	         )),
               CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left",-colspan=>"2"},"&nbsp;")).
               CGI::Tr({},
		CGI::td({-class=>"InfoPanel", -align=>"left",-colspan=>"2"}, $view_problem_line
	         )),
                CGI::end_table();
}

#####	 Version 3 is the problem library
# 
# This comes in 3 forms, problem library version 1, and for version 2 there
# is the basic, and the advanced interfaces.  This function checks what we are
# supposed to do, or aborts if the problem library has not been installed.

sub browse_library_panel {
	my $self=shift;
	my $lib = shift || '';
	my $r = $self->r;
	my $ce = $r->ce;

	# See if the problem library is installed
	my $libraryRoot = $r->{ce}->{problemLibrary}->{root};

	unless($libraryRoot) {
		print CGI::Tr(CGI::td(CGI::div({class=>'ResultsWithError', align=>"center"}, 
			"The problem library has not been installed.")));
		return;
	}
	# Test if the Library directory link exists.  If not, try to make it
	unless(-d "$ce->{courseDirs}->{templates}/Library") {
		unless(symlink($libraryRoot, "$ce->{courseDirs}->{templates}/Library")) {
			my $msg =	 <<"HERE";
You are missing the directory <code>templates/Library</code>, which is needed
for the Problem Library to function.	It should be a link pointing to
<code>$libraryRoot</code>, which you set in <code>conf/site.conf</code>.
I tried to make the link for you, but that failed.	Check the permissions
in your <code>templates</code> directory.
HERE
			$self->addbadmessage($msg);
		}
	}

	# Now check what version we are supposed to use
	my $libraryVersion = $r->{ce}->{problemLibrary}->{version} || 1;
	if($libraryVersion == 1) {
		return $self->browse_library_panel1;
	} elsif($libraryVersion >= 2 && $lib ne 'BPL') {
		return $self->browse_library_panel2	if($self->{library_basic}==1);
		return $self->browse_library_panel2adv;
	} elsif($libraryVersion >= 2 && $lib eq 'BPL') {
		return $self->browse_library_panel5	if($self->{library_basic}==1);
	} else {
		print CGI::Tr(CGI::td(CGI::div({class=>'ResultsWithError', align=>"center"}, 
			"The problem library version is set to an illegal value.")));
		return;
	}
}

sub browse_library_panel1 {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my @chaps = WeBWorK::Utils::ListingDB::getAllChapters($r->{ce});
	unshift @chaps, LIB2_DATA->{dbchapter}{all};
	my $chapter_selected = $r->param('library_chapters') || LIB2_DATA->{dbchapter}->{all};

	my @sects=();
	if ($chapter_selected ne LIB2_DATA->{dbchapter}{all}) {
		@sects = WeBWorK::Utils::ListingDB::getAllSections($r->{ce}, $chapter_selected);
	}

	unshift @sects, ALL_SECTIONS;
	my $section_selected =	$r->param('library_sections') || LIB2_DATA->{dbsection}{all};

	my $view_problem_line = view_problems_line('lib_view', $r->maketext('View Problems'), $self->r);

	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"}, 
		CGI::start_table(),
			CGI::Tr({},
				CGI::td([$r->maketext("Chapter"),
					CGI::popup_menu(-name=> 'library_chapters', 
					                -values=>\@chaps,
					                -default=> $chapter_selected
					),
					CGI::submit(-name=>"lib_select_chapter", -value=>"Update Section List")])),
			CGI::Tr({},
				CGI::td($r->maketext("Section")),
				CGI::td({-colspan=>2},
					CGI::popup_menu(-name=> 'library_sections', 
					                -values=>\@sects,
					                -default=> $section_selected
			))),

			CGI::Tr(CGI::td({-colspan=>3}, $view_problem_line)),
			CGI::end_table(),
		));
}

sub browse_library_panel2 {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r);
	unshift @subjs, LIB2_DATA->{dbsubject}{all};

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r);
	unshift @chaps, LIB2_DATA->{dbchapter}{all};

	my @sects=();
	@sects = WeBWorK::Utils::ListingDB::getAllDBsections($r);
	unshift @sects, LIB2_DATA->{dbsection}{all};

	my $subject_selected = $r->param('library_subjects') || LIB2_DATA->{dbsubject}{all};
	my $chapter_selected = $r->param('library_chapters') || LIB2_DATA->{dbchapter}{all};
	my $section_selected =	$r->param('library_sections') || LIB2_DATA->{dbsection}{all};

	my $view_problem_line = view_problems_line('lib_view', $r->maketext('View Problems'), $self->r);

	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r);
	if($count_line==0) {
		$count_line = $r->maketext("There are no matching WeBWorK problems");
	} else {
		$count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
	}

	print CGI::Tr({},
	    CGI::td({-class=>"InfoPanel", -align=>"left"}, 
		CGI::hidden(-name=>"library_is_basic", -default=>1,-override=>1),
		CGI::start_table({-width=>"100%"}),
		CGI::Tr({},
			CGI::td([$r->maketext("Subject:"),
				CGI::popup_menu(-name=> 'library_subjects', 
					            -values=>\@subjs,
					            -default=> $subject_selected
				)]),
#			CGI::td({-colspan=>2, -align=>"right"},
#				CGI::submit(-name=>"lib_select_subject", -value=>"Update Chapter/Section Lists"))
			CGI::td({-colspan=>2, -align=>"right"},
					CGI::submit(-name=>"library_advanced", -value=>$r->maketext("Advanced Search")))
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Chapter:"),
				CGI::popup_menu(-name=> 'library_chapters', 
					            -values=>\@chaps,
					            -default=> $chapter_selected
		    )]),
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Section:"),
			CGI::popup_menu(-name=> 'library_sections', 
					        -values=>\@sects,
					        -default=> $section_selected
		    )]),
		 ),
		 CGI::Tr(CGI::td({-colspan=>3}, $view_problem_line)),
		 CGI::Tr(CGI::td({-colspan=>3, -align=>"center", -id=>"library_count_line"}, $count_line)),
		 CGI::end_table(),
	 ));
	
}
sub browse_library_panel2t {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r);
	unshift @subjs, $r->maketext ( LIB2_DATA->{dbsubject}{all} );

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r);
	unshift @chaps, $r->maketext ( LIB2_DATA->{dbchapter}{all} );

	my @sects=();
	@sects = WeBWorK::Utils::ListingDB::getAllDBsections($r);
	unshift @sects, $r->maketext ( LIB2_DATA->{dbsection}{all} );

	my $subject_selected = $r->param('library_subjects') || $r->maketext ( LIB2_DATA->{dbsubject}{all} );
	my $chapter_selected = $r->param('library_chapters') || $r->maketext (  LIB2_DATA->{dbchapter}{all} );
	my $section_selected =	$r->param('library_sections') || $r->maketext ( LIB2_DATA->{dbsection}{all});

	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r);
	if($count_line==0) {
		$count_line = $r->maketext("There are no matching WeBWorK problems");
	} else {
		$count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
	}
	
	my $texts = WeBWorK::Utils::ListingDB::getDBTextbooks($r);
	my @textarray = map { $_->[0] }  @{$texts};
	my %textlabels = ();
	for my $ta (@{$texts}) {
		$textlabels{$ta->[0]} = $ta->[1]." by ".$ta->[2]." (edition ".$ta->[3].")";
	}
	if(! grep { $_ eq $r->param('library_textbook') } @textarray) {
		$r->param('library_textbook', '');
	}
	unshift @textarray, $r->maketext(LIB2_DATA->{textbook}{all});
	my $atb = $r->maketext(LIB2_DATA->{textbook}{all}); $textlabels{$atb} = $r->maketext(LIB2_DATA->{textbook}{all});

	my $textchap_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textchapter');
	my @textchaps = map { $_->[0] } @{$textchap_ref};
	if(! grep { $_ eq $r->param('library_textchapter') } @textchaps) {
		$r->param('library_textchapter', '');
	}
	unshift @textchaps, $r->maketext(LIB2_DATA->{textchapter}{all});

	my $textsec_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textsection');
	my @textsecs = map { $_->[0] } @{$textsec_ref};
	if(! grep { $_ eq $r->param('library_textsection') } @textsecs) {
		$r->param('library_textsection', '');
	}
	unshift @textsecs, $r->maketext(LIB2_DATA->{textsection}{all});

	my %selected = ();
	for my $j (qw( dbsection dbchapter dbsubject textbook textchapter textsection )) {
		$selected{$j} = $r->param(LIB2_DATA->{$j}{name}) || $r->maketext(LIB2_DATA->{$j}{all});
	}

	my $text_popup = CGI::popup_menu(-name => 'library_textbook',
									 -values =>\@textarray,
									 -labels => \%textlabels,
									 -style=>"width:800px;",
									 -default=>$selected{textbook},
									 -onchange=>"submit();return true"
									 );


	my $library_keywords = $r->param('library_keywords') || '';


	my $view_problem_line = view_problems_line('lib_view', $r->maketext('View Problems'), $self->r, 2);

	# Formatting level checkboxes by hand
	my @selected_levels_arr = $r->param('level');
	my %selected_levels = ();
	for my $j (@selected_levels_arr) {
		$selected_levels{$j} = 1;
	}
	my $mylevelline = '<table width="100%"><tr>';
	for my $j (1..6) {
		my $selected = '';
		$selected = ' checked' if(defined($selected_levels{$j}));
		$mylevelline .= "<td><label><input type='checkbox' name='level' value='$j' ";
		$mylevelline .= "$selected />$j</label></td>";
	}
	$mylevelline .= "<td>".$self->helpMacro("Levels")."</td>";
	$mylevelline .= '</tr></table>';
        my $defAdv = $r->param('library_adv_btn') || 1;
        my $btnText = $r->maketext("Advanced Search");
        
        $btnText = $r->maketext("Basic Search") if($defAdv == 2);
        
        my $noshow = 'display:none;';
	$noshow = '' if ($defAdv == 2);
        
        my $right_button_style = "width: 18ex";

        return CGI::start_table({-align=>"left",-width=>"80%",-id=>"opladv"}),
	       CGI::Tr({},
	       CGI::td({-class=>"InfoPanel",-width=>"80%", -align=>"left"}, 
	       CGI::hidden(-name=>"library_is_basic", -default=>1,-override=>1),
	       CGI::hidden(-name=>"library_adv_btn", -default=>$defAdv),
	       CGI::start_table({-width=>"100%"}),
               CGI::Tr({},
                    CGI::td({-colspan=>"3",-width=>"60%",-align=>"left",-style=>"font-weight:bold;"}, $r->maketext('All Selected Constraints Joined by "And"')),
                    CGI::td({-colspan=>"1",-width=>"40%", -align=>"right"},
                                "<span class='opladvsrch' style=".$noshow." >".CGI::submit(-name=>"lib_select_subject", -value=>$r->maketext("Update Menus"),-style=> $right_button_style)."</span>".
				CGI::submit(-id=>"library_advanced",-class=>"OPLAdvSearch",-name=>"library_advanced", -value=>$btnText))
               ),
	       CGI::Tr({},
	           CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Subject:")),
	           CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},CGI::popup_menu(-name=> 'library_subjects', 
					            -values=>\@subjs,
                                                    -style=>"width:800px;",
					            -default=> $subject_selected
					   )),
                  ),
		CGI::Tr({},
			CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Chapter:")),
			CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},CGI::popup_menu(-name=> 'library_chapters', 
					            -values=>\@chaps,
                                                    -style=>"width:800px;",
					            -default=> $chapter_selected
					  )),
		),
		CGI::Tr({},
			CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Section:")),
			CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},CGI::popup_menu(-name=> 'library_sections', 
					        -values=>\@sects,
                                                -style=>"width:800px;",
					        -default=> $section_selected
					)),
		 ),

                 CGI::Tr({-class=>'opladvsrch', style => $noshow},
			CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Textbook:")), 
                        CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},$text_popup),
		 ),
		 CGI::Tr({-class=>'opladvsrch', style => $noshow},
			CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Text chapter:")),
			CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},CGI::popup_menu(-name=> 'library_textchapter', 
					        -values=>\@textchaps,
					        -style=>"width:800px;",
					        -default=> $selected{textchapter},
					        -onchange=>"submit();return true"
					)),
		 ),
		 CGI::Tr({-class=>'opladvsrch', style => $noshow},
			CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Text section:")),
			CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},CGI::popup_menu(-name=> 'library_textsection', 
					        -values=>\@textsecs,
					        -style=>"width:800px;",
					        -default=> $selected{textsection},
					        -onchange=>"submit();return true"
					)),
		 ),
		 CGI::Tr({-class=>'opladvsrch', style => $noshow},
				 CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Level:")),
				 "<td colspan='3' align='left' width='85%'>$mylevelline</td>"
		 ),
		 CGI::Tr({-class=>'opladvsrch', style => $noshow},
		     CGI::td({-colspan=>"1",-width=>"25%"},$r->maketext("Keywords:")),
		     CGI::td({-colspan=>"3",-align=>"left",-width=>"85%"},
			 CGI::textfield(-name=>"library_keywords",
							-default=>$library_keywords,
							-override=>1,
							-size=>80))),

		 CGI::Tr(CGI::td({-colspan=>"4", -align=>"left",-width=>"100%", -id=>"library_count_line"}, $count_line)),
		 CGI::Tr(CGI::td({-colspan=>"4",-width=>"100%"}, $view_problem_line)),
		 CGI::end_table()
	 )),
        CGI::end_table();
	
}

sub browse_library_panel5t {
	my $self = shift;
	my $r = $self->r;

	my $ce = $r->ce;

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r,'BPL');
	unshift @subjs, $r->maketext ( LIB2_DATA->{dbsubject}{all} );

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r,'BPL');
	unshift @chaps, $r->maketext (  LIB2_DATA->{dbchapter}{all} );

	my $subject_selected = $r->param('blibrary_subjects') || $r->maketext ( LIB2_DATA->{dbsubject}{all} );
	my $chapter_selected = $r->param('blibrary_chapters') || $r->maketext ( LIB2_DATA->{dbchapter}{all} );
#	my $section_selected =	$r->param('blibrary_sections') || $r->maketext ( LIB2_DATA->{dbsection}{all} );
	my $search_bpl       =	$r->param('search_bpl') || '';


	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r,'BPL');
	if($count_line==0) {
		$count_line = $r->maketext("There are no matching WeBWorK problems");
	} else {
		$count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
	}
	my $view_problem_line = view_problems_line_bpl('lib_view_bpl', $r->maketext('View Problems'), $count_line,$self->r);

        # Option of whether to show hints and solutions
	my $defaultHints = $r->param('showHints') || SHOW_HINTS_DEFAULT;
	$defaultHints = 1;
	my $defaultSolutions = $r->param('showSolutions') || SHOW_SOLUTIONS_DEFAULT;
	$defaultSolutions = 1;
        my $defaultMax = $r->param('max_shown') || MAX_SHOW_DEFAULT;


	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
		@{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	# We have our own displayMode since its value may be None, which is illegal
	# in other modules.
	my $mydisplayMode = $r->param('mydisplayMode') || $r->ce->{pg}->{options}->{displayMode};


	#return #CGI::Tr({},
	    #CGI::td({-class=>"InfoPanel", -align=>"left"}, 
		#CGI::hidden(-name=>"max_shown",-id=>"max_shown", -value=>$defaultMax),
		#CGI::hidden(-name=>"showSolutions", -default=>1,-override=>1),
		#CGI::hidden(-name=>"library_is_basic", -default=>1,-override=>1),
		#CGI::hidden(-name=>"library_srchtype", -default=>'BPL',-override=>1,-value=>'BPL'),
                my $defaultKeywords = $r->param('library_defkeywords') || DEFAULT_KEYWORDS;
		return CGI::start_table({-width=>"100%"}),
                CGI::Tr({},
		    CGI::td([$r->maketext("Search").CGI::br().CGI::br(),
                    CGI::textfield(-name=>"search_bpl",
                                     -id=>"search_bpl",
                                     -type=>"text",
                                     -default=>$search_bpl,
                                     -class=>"search_bpl",
                                     -placeholder => $r->maketext("Enter keywords"),
                                           -example=>$r->maketext("Enter keywords"),
                                           -autocomplete=>"off",
                                           -override=>1
                                                                                        ).CGI::br()."<small class=\"text-muted\">".$r->maketext("Use the minus (-) signe before a keyword to tell the search to exclude problems with that term")."</small>",])
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Subject:"),
				CGI::popup_menu(-name=> 'blibrary_subjects', 
					            -values=>\@subjs,
                                                    -id=>'blibrary_subjects',
					            -default=> $subject_selected
				)]),
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Chapter:"),
				CGI::popup_menu(-name=> 'blibrary_chapters', 
                                                    -id=>'blibrary_chapters',
					            -values=>\@chaps,
					            -default=> $chapter_selected
		    )]),
		),
		 CGI::Tr(
                   CGI::td({-align=>"left",-valign=>"top"}, $r->maketext("Keywords")),
                   CGI::td({-colspan=>2}, "<span id='kword' class='kword'></span><br /><div align=\"left\"><a href=\"#\" id=\"load_kw\">+ ".$r->maketext ("Load More")."</a></div>")

                 ),
		 CGI::Tr(CGI::td({-colspan=>3, -align=>"left", -id=>"blibrary_count_line"}, $count_line)),
		 CGI::Tr(CGI::td({-colspan=>3}, $view_problem_line,
		                     CGI::hidden(-name=>"library_defkeywords",-id=>"library_defkeywords", -default=>$defaultKeywords,-override=>1))),


	        #CGI::Tr(CGI::td({-colspan=>3},
                #       "<input type=\"checkbox\" name=\"showHints\" value=\"on\" checked />Hints&nbsp;<input type=\"checkbox\" name=\"showSolutions\" value=\"on\" checked />Solutions",
                #CGI::checkbox(-name=>"showHints",-checked=>$defaultHints,-label=>$r->maketext("Hints")),
	        #CGI::checkbox(-name=>"showSolutions",-checked=>$defaultSolutions,-label=>$r->maketext("Solutions")),
                #CGI::popup_menu(-name=> 'max_shown',
                #                                    -values=>[5,10,15,20,25,30,50,$r->maketext("All")],
                 #                                   -default=> $defaultMax))),
		 CGI::end_table();
	 #);
	
}
sub browse_library_panel5ten {
	my $self = shift;
	my $r = $self->r;

	my $ce = $r->ce;

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r,'BPLEN');
	unshift @subjs, $r->maketext ( LIB2_DATA->{dbsubject}{all} );

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r,'BPLEN');
	unshift @chaps, $r->maketext (  LIB2_DATA->{dbchapter}{all} );

	my $subject_selected = $r->param('benlibrary_subjects') || $r->maketext ( LIB2_DATA->{dbsubject}{all} );
	my $chapter_selected = $r->param('benlibrary_chapters') || $r->maketext ( LIB2_DATA->{dbchapter}{all} );
#	my $section_selected =	$r->param('benlibrary_sections') || $r->maketext ( LIB2_DATA->{dbsection}{all} );
	my $search_bplen     =	$r->param('search_bplen') || '';


	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r,'BPLEN');
	if($count_line==0) {
		$count_line = $r->maketext("There are no matching WeBWorK problems");
	} else {
		$count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
	}
	my $view_problem_line = view_problems_line_bpl('lib_view_bplen', $r->maketext('View Problems'), $count_line,$self->r);

        # Option of whether to show hints and solutions
	my $defaultHints = $r->param('showHints') || SHOW_HINTS_DEFAULT;
	$defaultHints = 1;
	my $defaultSolutions = $r->param('showSolutions') || SHOW_SOLUTIONS_DEFAULT;
	$defaultSolutions = 1;
        my $defaultMax = $r->param('max_shown') || MAX_SHOW_DEFAULT;


	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
		@{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	# We have our own displayMode since its value may be None, which is illegal
	# in other modules.
	my $mydisplayMode = $r->param('mydisplayMode') || $r->ce->{pg}->{options}->{displayMode};


                my $defaultKeywords = $r->param('library_defkeywordsen') || DEFAULT_KEYWORDS;
		return CGI::start_table({-width=>"100%"}),
                CGI::Tr({},
		    CGI::td([$r->maketext("Search").CGI::br().CGI::br(),
                    CGI::textfield(-name=>"search_bplen",
                                     -id=>"search_bplen",
                                     -type=>"text",
                                     -default=>$search_bplen,
                                     -class=>"search_bplen",
                                     -placeholder => $r->maketext("Enter keywords"),
                                           -example=>$r->maketext("Enter keywords"),
                                           -autocomplete=>"off",
                                           -override=>1
                                                                                        ).CGI::br()."<small class=\"text-muted\">".$r->maketext("Use the minus (-) signe before a keyword to tell the search to exclude problems with that term")."</small>",])
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Subject:"),
				CGI::popup_menu(-name=> 'benlibrary_subjects', 
					            -values=>\@subjs,
                                                    -id=>'benlibrary_subjects',
					            -default=> $subject_selected
				)]),
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Chapter:"),
				CGI::popup_menu(-name=> 'benlibrary_chapters', 
                                                    -id=>'benlibrary_chapters',
					            -values=>\@chaps,
					            -default=> $chapter_selected
		    )]),
		),
		 CGI::Tr(
                   CGI::td({-align=>"left",-valign=>"top"}, $r->maketext("Keywords")),
                   CGI::td({-colspan=>2}, "<span id='kworden' class='kworden'></span><br /><div align=\"left\"><a href=\"#\" id=\"load_kwen\">+ ".$r->maketext ("Load More")."</a></div>")

                 ),
		 CGI::Tr(CGI::td({-colspan=>3, -align=>"left", -id=>"benlibrary_count_line"}, $count_line)),
		 CGI::Tr(CGI::td({-colspan=>3}, $view_problem_line,
		                     CGI::hidden(-name=>"library_defkeywordsen",-id=>"library_defkeywordsen", -default=>$defaultKeywords,-override=>1))),


		 CGI::end_table();
	
}
sub browse_library_panel2adv {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $right_button_style = "width: 18ex";

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r);
	if(! grep { $_ eq $r->param('library_subjects') } @subjs) {
		$r->param('library_subjects', '');
	}
	unshift @subjs, LIB2_DATA->{dbsubject}{all};

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r);
	if(! grep { $_ eq $r->param('library_chapters') } @chaps) {
		$r->param('library_chapters', '');
	}
	unshift @chaps, LIB2_DATA->{dbchapter}{all};

	my @sects = WeBWorK::Utils::ListingDB::getAllDBsections($r);
	if(! grep { $_ eq $r->param('library_sections') } @sects) {
		$r->param('library_sections', '');
	}
	unshift @sects, LIB2_DATA->{dbsection}{all};

	my $texts = WeBWorK::Utils::ListingDB::getDBTextbooks($r);
	my @textarray = map { $_->[0] }  @{$texts};
	my %textlabels = ();
	for my $ta (@{$texts}) {
		$textlabels{$ta->[0]} = $ta->[1]." by ".$ta->[2]." (edition ".$ta->[3].")";
	}
	if(! grep { $_ eq $r->param('library_textbook') } @textarray) {
		$r->param('library_textbook', '');
	}
	unshift @textarray, LIB2_DATA->{textbook}{all};
	my $atb = LIB2_DATA->{textbook}{all}; $textlabels{$atb} = LIB2_DATA->{textbook}{all};

	my $textchap_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textchapter');
	my @textchaps = map { $_->[0] } @{$textchap_ref};
	if(! grep { $_ eq $r->param('library_textchapter') } @textchaps) {
		$r->param('library_textchapter', '');
	}
	unshift @textchaps, LIB2_DATA->{textchapter}{all};

	my $textsec_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textsection');
	my @textsecs = map { $_->[0] } @{$textsec_ref};
	if(! grep { $_ eq $r->param('library_textsection') } @textsecs) {
		$r->param('library_textsection', '');
	}
	unshift @textsecs, LIB2_DATA->{textsection}{all};

	my %selected = ();
	for my $j (qw( dbsection dbchapter dbsubject textbook textchapter textsection )) {
		$selected{$j} = $r->param(LIB2_DATA->{$j}{name}) || LIB2_DATA->{$j}{all};
	}

	my $text_popup = CGI::popup_menu(-name => 'library_textbook',
									 -values =>\@textarray,
									 -labels => \%textlabels,
									 -default=>$selected{textbook},
									 -onchange=>"submit();return true");

	
	my $library_keywords = $r->param('library_keywords') || '';

	my $view_problem_line = view_problems_line('lib_view', $r->maketext('View Problems'), $self->r);

	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r);
	if($count_line==0) {
		$count_line = $r->maketext("There are no matching WeBWorK problems");
	} else {
		$count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
	}

	# Formatting level checkboxes by hand
	my @selected_levels_arr = $r->param('level');
	my %selected_levels = ();
	for my $j (@selected_levels_arr) {
		$selected_levels{$j} = 1;
	}
	my $mylevelline = '<table width="100%"><tr>';
	for my $j (1..6) {
		my $selected = '';
		$selected = ' checked' if(defined($selected_levels{$j}));
		$mylevelline .= "<td><label><input type='checkbox' name='level' value='$j' ";
		$mylevelline .= "$selected />$j</label></td>";
	}
	$mylevelline .= "<td>".$self->helpMacro("Levels")."</td>";
	$mylevelline .= '</tr></table>';

	print CGI::Tr({},
	  CGI::td({-class=>"InfoPanel", -align=>"left"},
		CGI::hidden(-name=>"library_is_basic", -default=>2,-override=>1),
		CGI::start_table({-width=>"100%"}),
		# Html done by hand since it is temporary
		CGI::Tr(CGI::td({-colspan=>4, -align=>"center"}, $r->maketext('All Selected Constraints Joined by "And"'))),
		CGI::Tr({},
			CGI::td([$r->maketext("Subject:"),
				CGI::popup_menu(-name=> 'library_subjects', 
					            -values=>\@subjs,	
					            -default=> $selected{dbsubject}
				)]),
			CGI::td({-colspan=>2, -align=>"right"},
				CGI::submit(-name=>"lib_select_subject", -value=>$r->maketext("Update Menus"),
					-style=> $right_button_style))),
		CGI::Tr({},
			CGI::td([$r->maketext("Chapter:"),
				CGI::popup_menu(-name=> 'library_chapters', 
					            -values=>\@chaps,
					            -default=> $selected{dbchapter}
		    )]),
			CGI::td({-colspan=>2, -align=>"right"},
					CGI::submit(-name=>"library_reset", -value=>$r->maketext("Reset"),
					-style=>$right_button_style))
		),
		CGI::Tr({},
			CGI::td([$r->maketext("Section:"),
			CGI::popup_menu(-name=> 'library_sections', 
					        -values=>\@sects,
					        -default=> $selected{dbsection}
		    )]),
			CGI::td({-colspan=>2, -align=>"right"},
					CGI::submit(-name=>"library_basic", -value=>$r->maketext("Basic Search"),
					-style=>$right_button_style))
		 ),
		 CGI::Tr({},
			CGI::td([$r->maketext("Textbook:"), $text_popup]),
		 ),
		 CGI::Tr({},
			CGI::td([$r->maketext("Text chapter:"),
			CGI::popup_menu(-name=> 'library_textchapter', 
					        -values=>\@textchaps,
					        -default=> $selected{textchapter},
							-onchange=>"submit();return true"
		    )]),
		 ),
		 CGI::Tr({},
			CGI::td([$r->maketext("Text section:"),
			CGI::popup_menu(-name=> 'library_textsection', 
					        -values=>\@textsecs,
					        -default=> $selected{textsection},
							-onchange=>"submit();return true"
		    )]),
		 ),
		 CGI::Tr({},
				 CGI::td($r->maketext("Level:")),
				 "<td>$mylevelline</td>"
		 ),
		 CGI::Tr({},
		     CGI::td($r->maketext("Keywords:")),CGI::td({-colspan=>2},
			 CGI::textfield(-name=>"library_keywords",
							-default=>$library_keywords,
							-override=>1,
							-size=>40))),
		 CGI::Tr(CGI::td({-colspan=>3}, $view_problem_line)),
		 #CGI::Tr(CGI::td({-colspan=>3, -align=>"center", -id=>"library_count_line"}, $count_line)),
		 CGI::end_table(),
	 ));
	
}
#####	 Search by specific library

sub browse_specific_panel {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $library_selected = shift || $r->param('library_lib');
	my $dir_selected = shift || $r->param('library_dir');
	my $subdir_selected = shift || $r->param('library_subdir');
        my @libs = ( );
	my @list_of_reps = ( );
        my @list_of_sub_reps = ( );
        my ($library_dir,$library_subdir);
        my $topdir = $ce->{courseDirs}{templates};

	my $default_value = $r->maketext(SELECT_SETDEF_FILE_STRING);

	foreach my $lib (sort(keys(%problib))) {
		push @libs, $lib if(-d "$ce->{courseDirs}{templates}/$lib");
	}
        unshift @libs,$r->maketext(ALL_LIBS);
	# in the following line, the parens after sort are important. if they are
	# omitted, sort will interpret get_set_defs as the name of the comparison
	# function, and ($ce->{courseDirs}{templates}) as a single element list to
	# be sorted. *barf*
        my $folder_to_check = $ce->{courseDirs}{templates};
        if($library_selected) {
            $folder_to_check = $ce->{courseDirs}{templates}."/".$library_selected;
	    @list_of_reps = sort(get_sub_reps($folder_to_check));
        }
        unshift @list_of_reps,$r->maketext( ALL_DIRS );
        if($dir_selected && $dir_selected ne 'All Dir') {
            $folder_to_check = $ce->{courseDirs}{templates}."/".$library_selected."/".$dir_selected;
	    @list_of_sub_reps = sort(get_sub_reps($folder_to_check));
        }
        unshift @list_of_sub_reps,$r->maketext( ALL_SUBDIRS );

        my $count_line;

	my $view_problem_line = view_problems_line_bpl('lib_view_spcf', $r->maketext('View Problems'),undef, $self->r);
	my $popupetc = CGI::popup_menu(-name=> 'library_lib',
                                -values=>\@libs,
                                -default=> $library_selected
                                ).
		CGI::hidden(-name=>"library_topdir", -default=>$topdir,-override=>1,-value=>$topdir).
		CGI::br();

	my $popupetc2 = CGI::popup_menu(-name=> 'library_dir',
                                -values=>\@list_of_reps,
                                -default=> $dir_selected).
		CGI::br();
	my $popupetc3 = CGI::popup_menu(-name=> 'library_subdir',
                                -values=>\@list_of_sub_reps,
                                -default=> $subdir_selected).
		CGI::br().CGI::br().  $view_problem_line;

	if(scalar(@libs) == 0) {
		$popupetc =  $r->maketext("there are no set problem libraries course to look at.");
	}
	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("Library"),
		$popupetc
	));
	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("Directory"),
		$popupetc2
	));
	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("SubDirectory"),
		$popupetc3
	));
       print  CGI::Tr(CGI::td({-colspan=>3, -align=>"center", -id=>"library_count_line"}, $count_line));

}
sub browse_specific_panelt {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $library_selected = shift || $r->param('library_lib');
	my $dir_selected = shift || $r->param('library_dir');
	my $subdir_selected = shift || $r->param('library_subdir');
        my @libs = ( );
	my @list_of_reps = ( );
        my @list_of_sub_reps = ( );
        my ($library_dir,$library_subdir);
        my $topdir = $ce->{courseDirs}{templates};

	my $default_value = $r->maketext(SELECT_SETDEF_FILE_STRING);
	
	foreach my $lib (sort(keys(%problib))) {
                push @libs, $lib if(-d "$ce->{courseDirs}{templates}/$lib");
        }

        unshift @libs,$r->maketext(ALL_LIBS);
	# in the following line, the parens after sort are important. if they are
	# omitted, sort will interpret get_set_defs as the name of the comparison
	# function, and ($ce->{courseDirs}{templates}) as a single element list to
	# be sorted. *barf*
        my $folder_to_check = $ce->{courseDirs}{templates};
        if($library_selected && $library_selected ne $r->maketext("Select Library")) {
            $folder_to_check = $ce->{courseDirs}{templates}."/".$library_selected;
	    @list_of_reps = sort(get_sub_reps($folder_to_check));
        }
        unshift @list_of_reps,$r->maketext(ALL_DIRS);
        if($dir_selected && $dir_selected ne $r->maketext("All Directories")) {
            $folder_to_check = $ce->{courseDirs}{templates}."/".$library_selected."/".$dir_selected;
	    @list_of_sub_reps = sort(get_sub_reps($folder_to_check));
        }
        unshift @list_of_sub_reps,$r->maketext(ALL_SUBDIRS);

        my $count_line = WeBWorK::Utils::ListingDB::countDirListings($r);
        if($count_line==0) {
                $count_line = $r->maketext("There are no matching WeBWorK problems");
        } else {
                $count_line = $r->maketext("There are [_1] matching WeBWorK problems", $count_line);
        }


	my $view_problem_line = view_problems_line_bpl('lib_view_spcf', $r->maketext('View Problems'),undef, $self->r);


	my $popupetc = CGI::popup_menu(-name=> 'library_lib',
                                -values=>\@libs,
                                -default=> $library_selected
                                ).
		CGI::hidden(-name=>"library_topdir", -default=>$topdir,-override=>1,-value=>$topdir).
		CGI::br();

	my $popupetc2 = CGI::popup_menu(-name=> 'library_dir',
                                -values=>\@list_of_reps,
                                -default=> $dir_selected).
		CGI::br();
	my $popupetc3 = CGI::popup_menu(-name=> 'library_subdir',
                                -values=>\@list_of_sub_reps,
                                -default=> $subdir_selected).
                CGI::br();
        my $popupetc4 =  $view_problem_line;

	if(scalar(@libs) == 0) {
		$popupetc = $r->maketext("there are no set problem libraries course to look at.");
	}

	return CGI::start_table({-width=>"80%",-align=>"left"}),

        CGI::Tr(CGI::td([$r->maketext("Library"), $popupetc])),
        CGI::Tr(CGI::td([$r->maketext("Directory"), $popupetc2])),
        CGI::Tr(CGI::td([$r->maketext("SubDirectory"), $popupetc3])),

        CGI::Tr(CGI::td({-colspan=>2, -align=>"left", -id=>"slibrary_count_line"}, $count_line)),
        CGI::Tr(CGI::td({-colspan=>2},[$popupetc4])),
        CGI::end_table();

}
#####	 Version 4 is the set definition file panel

sub browse_setdef_panel {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $library_selected = shift;
	my $default_value = $r->maketext(SELECT_SETDEF_FILE_STRING);
	# in the following line, the parens after sort are important. if they are
	# omitted, sort will interpret get_set_defs as the name of the comparison
	# function, and ($ce->{courseDirs}{templates}) as a single element list to
	# be sorted. *barf*
	my @list_of_set_defs = sort(get_set_defs($ce->{courseDirs}{templates}));
	if(scalar(@list_of_set_defs) == 0) {
		@list_of_set_defs = ($r->maketext(NO_LOCAL_SET_STRING));
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		unshift @list_of_set_defs, $default_value; 
		$library_selected = $default_value; 
	}
	my $view_problem_line = view_problems_line('view_setdef_set', $r->maketext('View Problems'), $self->r);
	my $popupetc = CGI::popup_menu(-name=> 'library_sets',
                                -values=>\@list_of_set_defs,
                                -default=> $library_selected).
		CGI::br().  $view_problem_line;
	if($list_of_set_defs[0] eq $r->maketext(NO_LOCAL_SET_STRING)) {
		$popupetc = $r->maketext("there are no set definition files in this course to look at.");
	}
	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"}, $r->maketext("Browse from")." ",
		$popupetc
	));
}
sub browse_setdef_panelt {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $library_selected = shift;
	my $library_selected = $self->{current_library_set};
	my $default_value = $r->maketext(SELECT_SETDEF_FILE_STRING);
	
	# in the following line, the parens after sort are important. if they are
	# omitted, sort will interpret get_set_defs as the name of the comparison
	# function, and ($ce->{courseDirs}{templates}) as a single element list to
	# be sorted. *barf*
	my @list_of_set_defs = sort(get_set_defs($ce->{courseDirs}{templates}));
	unshift @list_of_set_defs, $default_value; 
	
	if(scalar(@list_of_set_defs) == 0) {
		@list_of_set_defs = ($r->maketext(NO_LOCAL_SET_STRING));
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		#unshift @list_of_set_defs, $default_value; 
		$library_selected = $default_value; 
	}
	my $view_problem_line = view_problems_line('view_setdef_set', $r->maketext('View Problems'), $self->r, 5);
	my $popupetc = CGI::popup_menu(-name=> 'slibrary_sets',
                                -values=>\@list_of_set_defs,
                                -default=> $library_selected);
	if($list_of_set_defs[0] eq $r->maketext(NO_LOCAL_SET_STRING)) {
		$popupetc = $r->maketext("there are no set definition files in this course to look at.");
	}
							
	return CGI::start_table({-align=>"left",-width=>"80%"}),
	       CGI::Tr({},
		   CGI::td({-class=>"InfoPanel", -align=>"left"},[ $r->maketext("Browse from").' ',$popupetc ])),
		   CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left",-colspan=>"2"},"&nbsp;")).
	       CGI::Tr({},
		   CGI::td({-class=>"InfoPanel", -align=>"left",-colspan=>"2"}, $view_problem_line)),
           CGI::end_table();
     
}
sub make_top_row {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my %data = @_;

	my $list_of_local_sets = $data{all_db_sets};
	my $have_local_sets = scalar(@$list_of_local_sets);
	my $browse_which = $data{browse_which};
	my $library_selected = $self->{current_library_set};
	my $set_selected = $r->param('local_sets');
	my (@dis1, @dis2, @dis3, @dis4) = ();
	@dis1 =	 (-disabled=>1) if($browse_which eq 'browse_npl_library');	 
	@dis2 =	 (-disabled=>1) if($browse_which eq 'browse_local');
	@dis3 =	 (-disabled=>1) if($browse_which eq 'browse_mysets');
	@dis4 =	 (-disabled=>1) if($browse_which eq 'browse_setdefs');

	##	Make buttons for additional problem libraries
	my $libs = '';
	foreach my $lib (sort(keys(%problib))) {
		$libs .= ' '. CGI::submit(-name=>"browse_$lib", -value=>Encode::decode("UTF-8",$problib{$lib}),
																 ($browse_which eq "browse_$lib")? (-disabled=>1): ())
			if (-d "$ce->{courseDirs}{templates}/$lib");
	}
	#$libs = CGI::br().$r->maketext("or Problems from").$libs if $libs ne '';

	my $these_widths = "width: 25ex";

	if($have_local_sets ==0) {
		$list_of_local_sets = [$r->maketext(NO_LOCAL_SET_STRING)];
	} elsif (not defined($set_selected) or $set_selected eq ""
	  or $set_selected eq $r->maketext(SELECT_SET_STRING)) {
		unshift @{$list_of_local_sets}, $r->maketext(SELECT_SET_STRING);
		$set_selected = $r->maketext(SELECT_SET_STRING);
	}
	#my $myjs = 'document.mainform.selfassign.value=confirm("Should I assign the new set to you now?\nUse OK for yes and Cancel for no.");true;';
        my $courseID = $self->r->urlpath->arg("courseID");

        #Tusar - 3/25/17
        print CGI::Tr(CGI::td({-class =>"InfoPanel", -align=>"left", -colspan =>"2"},CGI::h2($r->maketext("Homework set to add problems to")).' ', 
           ));
           
        my $c = 0;
	my $btn_click = "lib_view_bpl";

        if($self->{browse_which} eq 'browse_bplen_library') {
           $c = 1;
	   $btn_click = "lib_view_bplen";
        }
        if($self->{browse_which} eq 'browse_spcf_library') {
           $c = 6;
	   $btn_click = "lib_view_spcf";
        }
        if($self->{browse_which} eq 'browse_npl_library') {
           $c = 2;
	   $btn_click = "lib_view";
        }
        if($self->{browse_which} eq 'browse_local') {
           $c = 3;
	   $btn_click = "view_local_set";
        }
        if($self->{browse_which} eq 'browse_mysets') {
           $c = 4;
	   $btn_click = "view_mysets_set";
        }
        if($self->{browse_which} eq 'browse_setdefs') {
           $c = 5;
	   $btn_click = "view_setdef_set";
        }
        print CGI::Tr(CGI::td({-class =>"InfoPanel", -align=>"left"},
                             CGI::start_table({-border=>"0"}),
                                CGI::Tr( CGI::td({-class =>"InfoPanel", -align=>"left"},[
                                    $r->maketext("Select an Existing Set").' ',
                                    CGI::popup_menu(-name=> 'local_sets',
                                                -values=>$list_of_local_sets,
                                                -default=> $set_selected,
                                                -onchange=> "return markinset()",
                                                -override=>1).
                                    CGI::submit(-name=>"edit_local", -value=>$r->maketext("Edit Target Set")),
                                    CGI::hidden(-name=>"selfassign", -default=>0,-override=>1),
                                ])),
                                CGI::Tr(CGI::td({-class =>"InfoPanel", -align=>"left"},[
                                       $r->maketext("Create a New Set"),
                                       CGI::textfield(-name=>"new_set_name",
                                           -example=>$r->maketext("Name for new set here"),
                                           -placeholder=>$r->maketext("Name for new set here"),
                                           -override=>1, -size=>30).
                                       CGI::submit(-name=>"new_local_set", -value=>$r->maketext("Create"),
                                       -onclick=>"document.mainform.selfassign.value=1"      #       $myjs
                                       #-onclick=>"createNewSet()"      #       $myjs)
                                       ),
                                ])),
                             CGI::end_table(),
        ));

	print CGI::hidden(-name=>"lib_deftab", -default=>$c,-override=>1);


	print CGI::Tr(CGI::td({class=>'table-separator'}));
	print CGI::Tr(CGI::td( CGI::br() ));

	# Tidy this list up since it is used in two different places
	if ($list_of_local_sets->[0] eq $r->maketext(SELECT_SET_STRING)) {
		shift @{$list_of_local_sets};
	}

	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"left"},
                        CGI::h2($r->maketext("Library in which to search for existing problems")),
	));
        my @formsToShow = @{ VIEW_FORMS() };
        my @divArr = ();
        my @tabArr = ();

  	my $default_choice = $formsToShow[$c];
  	
	foreach my $actionID (@formsToShow) {
		
		my $actionForm = %{ ACTION_FORMS() }{$actionID};

		my $active = "";
		$active = "active" if( $default_choice eq $actionID );

		push(@tabArr, CGI::li({ class => $active },
				CGI::a({ href => "#$actionID", data_toggle => "tab", class => "action-link", data_action => $actionID },
					$r->maketext(ucfirst(WeBWorK::split_cap($actionID))))));
		push(@divArr, CGI::div({ class => "tab-pane $active", id => $actionID },
				$self->$actionForm($self->getActionParams($actionID))));
	}
	
	print CGI::hidden(-name => 'action', -id => 'current_action', -value => $default_choice);
	print CGI::Tr(CGI::td({-class=>"InfoPanel", -align=>"center"},
              CGI::div({-class=>"tabber"},
              CGI::ul({-class => "nav nav-tabs"}, @tabArr),
               CGI::div({-class=>"tab-content"},@divArr))
	));

	

	print CGI::Tr(CGI::td({class=>'table-separator'}));

    # For next/previous buttons
	my ($next_button, $prev_button) = ("", "");
	my $show_hide_path_button = "";
	my $first_shown = $self->{first_shown};
	my $last_shown = $self->{last_shown}; 
	my $first_index = $self->{first_index};
	my $last_index = $self->{last_index}; 
	my @pg_files = @{$self->{pg_files}};

	if ($first_index > 0) {
		$prev_button = CGI::submit(-name=>"prev_page", -style=>"width:18ex",
						 -value=>$r->maketext("Previous page")
						 );
	}
	# This will have to be trickier with MLT
	if ((1+$last_index)<scalar(@pg_files)) {
		$next_button = CGI::submit(-name=>"next_page", -style=>"width:18ex",
						 -value=>$r->maketext("Next page")
						 );
	}
        my $clear_prob_btn = "";
	if (scalar(@pg_files)) {
                $show_hide_path_button  = "";
                my $bbrowse_which = $r->param('bbrowse_which') || 'browse_bpl_library';

                my $defaultMax = $r->param('max_shownt') || MAX_SHOW_DEFAULT;
                my $displayMax = ' '.$r->maketext('Max. Shown:').' '.
                CGI::popup_menu(-name=> 'max_shownt',id=>'max_shownt',
                                -values=>[5,10,15,20,25,30,50,$r->maketext("All")],
                                -onchange => "document.getElementById(\"$btn_click\").click();",
                                -default=> $defaultMax);
                #my ($chk_hintt,$chk_solnt) = ("","");
                #if($r->param('showHintt')) {
                #   $chk_hintt = " checked";
                #}
                #if($r->param('showSolutiont')) {
                #   $chk_solnt = " checked";
                #}
                

		$show_hide_path_button .= CGI::button(-name=>"select_all", -style=>"width:29ex",
			                               -value=>$r->maketext("Add All"));
		$show_hide_path_button .= $displayMax;
		#$show_hide_path_button .= "<input type=\"checkbox\" id=\"showHintt\" name=\"showHintt\" value=\"on\" onclick=\"toggleHint(\$(this));\" $chk_hintt />".$r->maketext("Hints")."&nbsp;<input type=\"checkbox\" id=\"showSolutiont\" name=\"showSolutiont\"/>".$r->maketext("Solutions")."&nbsp;";
                $show_hide_path_button .= $prev_button."&nbsp;".$next_button;
	}
	
        my $divtag =  "<div id='ShowResultsMenu' name='showResultsMenu' class='showResultsMenu'>";


	print CGI::Tr({},
		CGI::td({-class=>"InfoPanel", -align=>"center"},
			CGI::start_table({-border=>"0"}),
			CGI::Tr({}, CGI::td({ -align=>"center"},
			$divtag,$show_hide_path_button."</div>"
				)),
			CGI::end_table()));
}

sub getActionParams {
        my ($self, $actionID) = @_;
        my $r = $self->{r};

        my %actionParams;
        foreach my $param ($r->param) {
                next unless $param =~ m/^action\.$actionID\./;
                $actionParams{$param} = [ $r->param($param) ];
        }
        return %actionParams;
}


sub make_data_row {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->{ce};
	my $sourceFileData = shift;
	my $sourceFileName = $sourceFileData->{filepath};
	my $pg_file = shift;
	my $isstatic = $sourceFileData->{static};
	my $isMO = $sourceFileData->{MO};
	if (not defined $isMO) {
		($isMO, $isstatic) = getDBextras($r, $sourceFileName);
	}
	my $cnt = shift;
	my $mltnumleft = shift;

	$sourceFileName =~ s|^./||; # clean up top ugliness

	my $urlpath = $self->r->urlpath;
	my $db = $self->r->db;

	## to set up edit and try links elegantly we want to know if
	##    any target set is a gateway assignment or not
	my $localSet = $self->r->param('local_sets');
	my $setRecord;
	if ( defined($localSet) && $localSet ne $r->maketext(SELECT_SET_STRING) &&
	     $localSet ne $r->maketext(NO_LOCAL_SET_STRING) ) {
		$setRecord = $db->getGlobalSet( $localSet );
	}
	my $isGatewaySet = (defined($setRecord) && $setRecord->assignment_type =~ /gateway/);


	my $problem_seed = $self->{'problem_seed'} || 1234;
	my $edit_link = CGI::a({href=>$self->systemLink(
				$urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", $r, 
					courseID =>$urlpath->arg("courseID"),
					setID=>"Undefined_Set",
					problemID=>"1"),
				params=>{sourceFilePath => "$sourceFileName", 
					problemSeed=> $problem_seed}
			), 
			id=> "editit$cnt",
			target=>"WW_Editor", title=>$r->maketext("Edit it")}, CGI::i({ class => 'icon fas fa-pencil-alt', data_alt => 'edit', aria_hidden => "true" }, ""));
	
	my $displayMode = $self->r->param("mydisplayMode");
	$displayMode = $self->r->ce->{pg}->{options}->{displayMode}
		if not defined $displayMode or $displayMode eq "None";
	my $module = ( $isGatewaySet ) ? "GatewayQuiz" : "Problem";
	my %pathArgs = ( courseID =>$urlpath->arg("courseID"),
			setID=>"Undefined_Set" );
	$pathArgs{problemID} = "1" if ( ! $isGatewaySet );

	my $try_link = CGI::a({href=>$self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::$module", $r, 
			%pathArgs ),
			params =>{
				effectiveUser => scalar($self->r->param('user')),
				editMode => "SetMaker",
				problemSeed=> $problem_seed,
				sourceFilePath => "$sourceFileName",
				displayMode => $displayMode,
			}
		), target=>"WW_View", 
			title=>$r->maketext("Try it"),
			id=>"tryit$cnt",
			style=>"text-decoration: none"}, '<i class="far fa-eye" ></i>');

	my $inSet = CGI::span({ class => "lb-inset", id => "inset$cnt" },
		CGI::i(CGI::b($self->{isInSet}{$sourceFileName} ? " ".$r->maketext("(in target set)") : "&nbsp;")));
	my $fpathpop = "<span id=\"thispop$cnt\">$sourceFileName</span>";

	# saved CGI::span({-style=>"float:left ; text-align: left"},"File name: $sourceFileName "), 

	my $mlt = '';
	my ($mltstart, $mltend) = ('','');
	my $noshowclass = 'NS'.$cnt;
	$noshowclass = 'MLT'.$sourceFileData->{morelt} if $sourceFileData->{morelt};
	if($sourceFileData->{children}) {
		my $numchild = scalar(@{$sourceFileData->{children}});
		$mlt = "<span class='lb-mlt-parent' id='mlt$cnt' data-mlt-cnt='$cnt' data-mlt-noshow-class='$noshowclass' title='Show $numchild more like this' style='cursor:pointer'>M</span>";
		$noshowclass = "NS$cnt";
		$mltstart = "<tr><td><table id='mlt-table$cnt' class='lb-mlt-group'>\n";
	}
	$mltend = "</table></td></tr>\n" if($mltnumleft==0);
	my $noshow = '';
	$noshow = 'display: none' if($sourceFileData->{noshow});

	# Include tagwidget?
	my $tagwidget = '';
	my $user = scalar($r->param('user'));
	if ($r->authz->hasPermissions($user, "modify_tags")) {
		my $tagid = 'tagger'.$cnt;
		$tagwidget =  CGI::div({id=>$tagid}, '');
		my $templatedir = $r->ce->{courseDirs}->{templates};
		my $sourceFilePath = $templatedir .'/'. $sourceFileName;
		$sourceFilePath =~ s/'/\\'/g;
		my $site_url = $r->ce->{webworkURLs}->{htdocs};
		#$tagwidget .= CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/TagWidget/tagwidget.js"}). CGI::end_script();
		$tagwidget .= CGI::start_script({type=>"text/javascript"}). "mytw$cnt = new tag_widget('$tagid','$sourceFilePath')".CGI::end_script();
	}

	my $level =0;

	my $randomizetitle = $r->maketext("Randomize");
	my $rerand = $isstatic ? '' : qq{<span style="display: inline-block" class="rerandomize_problem_button" data-target-problem="$cnt" title="$randomizetitle")"><i class="fas fa-random"></i></span>};
	my $MOtag = $isMO ?  $self->helpMacro("UsesMathObjects",'<img src="/webwork2_files/images/pibox.png" border="0" title="Uses Math Objects" alt="Uses Math Objects" />') : '';
	$MOtag = '<span class="motag">'.$MOtag.'</span>';

	# get statistics to display
	
	my $global_problem_stats = '';
	if ($ce->{problemLibrary}{showLibraryGlobalStats}) {
	    my $stats = $self->{library_stats_handler}->getGlobalStats($sourceFileName);
	    if ($stats->{students_attempted}) {
		$global_problem_stats =    $self->helpMacro("Global_Usage_Data",$r->maketext('GLOBAL Usage')).': '.
					   $stats->{students_attempted}.', '.
                                           $self->helpMacro("Global_Average_Attempts_Data",$r->maketext('Attempts')).': '.
					   wwRound(2,$stats->{average_attempts}).', '.
                                           $self->helpMacro("Global_Average_Status_Data",$r->maketext('Status')).': '.
					   wwRound(0,100*$stats->{average_status}).'%;&nbsp;';
	    }
	}
	
		
	my $local_problem_stats = '';
	if ($ce->{problemLibrary}{showLibraryLocalStats}) {
	    my $stats = $self->{library_stats_handler}->getLocalStats($sourceFileName);
	    if ($stats->{students_attempted}) {
		$local_problem_stats =     $self->helpMacro("Local_Usage_Data",$r->maketext('LOCAL Usage')).': '.
					   $stats->{students_attempted}.', '.
                                           $self->helpMacro("Local_Average_Attempts_Data",$r->maketext('Attempts')).': '.
					   wwRound(2,$stats->{average_attempts}).', '.
                                           $self->helpMacro("Local_Average_Status_Data",$r->maketext('Status')).': '.
					   wwRound(0,100*$stats->{average_status}).'%&nbsp;';
	    }
	}

        my $problem_stats = '';
        if ($global_problem_stats or $local_problem_stats) {
                $problem_stats = CGI::span({class=>"lb-problem-stats"},
                                    $global_problem_stats . $local_problem_stats );
        }


	print $mltstart;
	# Print the cell
	print CGI::Tr({ align => "left", id => "pgrow$cnt", style => $noshow, class => "lb-problem-row $noshowclass" },
		CGI::td(CGI::div({ class => 'well' },
				CGI::div({-class=>"lb-problem-header"},
					CGI::span({ class => "lb-problem-add" },
						CGI::button(-name=>"add_me",
							value => $r->maketext("Add"),
							title => $r->maketext("Add problem to target set"),
							data_source_file => $sourceFileName)),
					CGI::span({-class=>"lb-problem-icons"},
						$MOtag, $mlt, $rerand,
						$edit_link, " ", $try_link,
						CGI::span({
								name => "dont_show", title => $r->maketext("Hide this problem"),
								style => "cursor: pointer", data_row_cnt => $cnt
							}, "X")),
					$problem_stats,
				),
				CGI::div({ class => "lb-problem-sub-header" }, CGI::span({ class => "lb-problem-path" }, $sourceFileName) . $inSet),
				CGI::hidden(-name=>"filetrial$cnt", -default=>$sourceFileName,-override=>1),
				$tagwidget,
				CGI::div(CGI::div({ class => "psr_render_area", id => "psr_render_area_$cnt", data_pg_file => $pg_file }))
			)
		));
	print $mltend;
}

sub clear_default {
	my $r = shift;
	my $param = shift;
	my $default = shift;
	my $newvalue = $r->param($param) || '';
	$newvalue = '' if($newvalue eq $default);
	$r->param($param, $newvalue);
}

### Mainly deal with more like this

sub process_search {
	my $r = shift;
	my $typ = shift || "";
        my $ce = $r->ce;
        my $bplroot = $ce->{problemLibrary}{BPLroot};
	my @dbsearch = @_;
	# Build a hash of MLT entries keyed by morelt_id
	my %mlt = ();
	my $mltind;
	for my $indx (0..$#dbsearch) {
           if($r->param('bbrowse_which') eq 'browse_bpl_library') {
		$dbsearch[$indx]->{filepath} = "BPL/".$dbsearch[$indx]->{path}."/".$dbsearch[$indx]->{filename};
           } elsif($r->param('bbrowse_which') eq 'browse_bplen_library') {
		$dbsearch[$indx]->{filepath} = "BPL/CCDMD-EN/".$dbsearch[$indx]->{path}."/".$dbsearch[$indx]->{filename};
           } else {
                if($r->param('bbrowse_which') eq 'browse_spcf_library') {
		   $dbsearch[$indx]->{filepath} = $dbsearch[$indx]->{path}."/".$dbsearch[$indx]->{filename};
                } else {
		   $dbsearch[$indx]->{filepath} = "Library/".$dbsearch[$indx]->{path}."/".$dbsearch[$indx]->{filename};
                }
           }
# For debugging
$dbsearch[$indx]->{oindex} = $indx;
		if($mltind = $dbsearch[$indx]->{morelt}) {
			if(defined($mlt{$mltind})) {
				push @{$mlt{$mltind}}, $indx;
			} else {
				$mlt{$mltind} = [$indx];
			}
		}
	}
	# Now filepath is set and we have a hash of mlt entries

	# Find MLT leaders, mark entries for no show,
	# set up children array for leaders
	for my $mltid (keys %mlt) {
		my @idlist = @{$mlt{$mltid}};
		if(scalar(@idlist)>1) {
			my $leader = WeBWorK::Utils::ListingDB::getMLTleader($r, $mltid) || 0;
			my $hold = undef;
			for my $subindx (@idlist) {
				if($dbsearch[$subindx]->{pgid} == $leader) {
					$dbsearch[$subindx]->{children}=[];
					$hold = $subindx;
				} else {
					$dbsearch[$subindx]->{noshow}=1;
				}
			}
			do { # we did not find the leader
				$hold = $idlist[0];
				$dbsearch[$hold]->{noshow} = undef;
				$dbsearch[$hold]->{children}=[];
			} unless($hold);
			$mlt{$mltid} = $dbsearch[$hold]; # store ref to leader
		} else { # only one, no more
			$dbsearch[$idlist[0]]->{morelt} = 0;
			delete $mlt{$mltid};
		}
	}

	# Put children in leader and delete them, record index of leaders
	$mltind = 0;
	while ($mltind < scalar(@dbsearch)) {
		if($dbsearch[$mltind]->{noshow}) {
			# move the entry to the leader
			my $mltval = $dbsearch[$mltind]->{morelt};
			push @{$mlt{$mltval}->{children}}, $dbsearch[$mltind];
			splice @dbsearch, $mltind, 1;
		} else {
			if($dbsearch[$mltind]->{morelt}) { # a leader
				for my $mltid (keys %mlt) {
					if($mltid == $dbsearch[$mltind]->{morelt}) {
						$mlt{$mltid}->{index} = $mltind;
						last;
					}
				}
			}
			$mltind++;
		}
	}
	# Last pass, reinsert children into dbsearch
	my @leaders = keys(%mlt);
	@leaders = reverse sort {$mlt{$a}->{index} <=> $mlt{$b}->{index}} @leaders;
	for my $i (@leaders) {
		my $base = $mlt{$i}->{index};
		splice @dbsearch, $base+1, 0, @{$mlt{$i}->{children}};
	}

	return @dbsearch;
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	## For all cases, lets set some things
	$self->{error}=0;
	my $ce = $r->ce;
	my $db = $r->db;
	my $maxShown =  $r->param('max_shownt') || $r->param('max_shown') || MAX_SHOW_DEFAULT;
	$maxShown = 10000000 if($maxShown eq $r->maketext("All")); # let's hope there aren't more
	my $library_basic = $r->param('library_is_basic') || 1;
	$self->{problem_seed} = $r->param('problem_seed') || 1234;
	## Fix some parameters
	for my $key (keys(%{ LIB2_DATA() })) {
		clear_default($r, LIB2_DATA->{$key}->{name}, LIB2_DATA->{$key}->{all} );
	}
	##  Grab library sets to display from parameters list.  We will
	##  modify this as we go through the if/else tree
        my $check_library = "llibrary_sets";
        my $browse_which = $r->param('bbrowse_which') || 'browse_bpl_library';

        if($browse_which eq 'browse_local') {
           $check_library = 'llibrary_sets';
        }
        if($browse_which eq 'browse_mysets') {
           $check_library = 'mlibrary_sets';
        }
        if($browse_which eq 'browse_setdefs') {
           $check_library = 'slibrary_sets';
        }

	$self->{current_library_set} =  $r->param($check_library);
    
	##	These directories will have individual buttons
	%problib = %{$ce->{courseFiles}{problibs}} if $ce->{courseFiles}{problibs};

	my $userName = $r->param('user');
	my $user = $db->getUser($userName); # checked 
	die "record for user $userName (real user) does not exist." 
		unless defined $user;
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		return(""); # Error message already produced in the body
	}

	## Now one action we have to deal with here
	if ($r->param('edit_local')) {
		my $urlpath = $r->urlpath;
		my $db = $r->db;
		my $checkset = $db->getGlobalSet($r->param('local_sets'));
		if (not defined($checkset)) {
			$self->{error} = 1;
			$self->addbadmessage($r->maketext('You need to select a "Target Set" before you can edit it.'));
		} else {
			my $page = $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::ProblemSetDetail',  $r, setID=>$r->param('local_sets'), courseID=>$urlpath->arg("courseID"));
			my $url = $self->systemLink($page);
			$self->reply_with_redirect($url);
		}
	}

	## Next, lots of set up so that errors can be reported with message()

	############# List of problems we have already printed

	$self->{past_problems} = get_past_problem_files($r);
	# if we don't end up reusing problems, this will be wiped out
	# if we do redisplay the same problems, we must adjust this accordingly
	my $none_shown = scalar(@{$self->{past_problems}})==0;
	my @pg_files=();
	my $use_previous_problems = 1;
	my $first_shown = $r->param('first_shown') || 0;
	my $last_shown = $r->param('last_shown'); 
	if (not defined($last_shown)) {
		$last_shown = -1; 
	}
	my $first_index = $r->param('first_index') || 0;
	my $last_index = $r->param('last_index');
	if (not defined($last_index)) {
		$last_index = -1; 
	}
	my $total_probs = $r->param('total_probs') || 0;
	my @all_past_list = (); # these are include requested, but not shown
	my ($j, $count, $omlt, $nmlt, $hold) = (0,0,-1,0,0);
	while (defined($r->param("all_past_list$j"))) {
		$nmlt = $r->param("all_past_mlt$j") || 0;
		push @all_past_list, {'filepath' => $r->param("all_past_list$j"), 'morelt' => $nmlt};
		if($nmlt != $omlt or $nmlt == 0) {
			$count++ if($j>0);
			if($j>$hold+1) {
				$all_past_list[$hold]->{children} = [2..($j-$hold)];
			}
			$omlt = $nmlt;
			$hold = $j;
		} else { # equal and nonzero, so a child
			$all_past_list[$j]->{noshow} = 1;
		}
		$j++;
	}
	if($nmlt && $j-$hold>1) { $all_past_list[$hold]->{children} = [ 2..($j-$hold)]; }
	$count++ if($j>0);

	############# Default of which problem selector to display

	$browse_which = $r->param('bbrowse_which') || 'browse_bpl_library';

	## check for problem lib buttons
	my $browse_lib = '';
	foreach my $lib (keys %problib) {
		if ($r->param("browse_$lib")) {
			$browse_lib = "browse_$lib";
			last;
		}
	}

	########### Start the logic through if elsif elsif ...
    debug("browse_lib", $r->param("$browse_lib"));
    debug("browse_npl_library", $r->param("browse_npl_library"));
    debug("browse_mysets", $r->param("browse_mysets"));
    debug("browse_setdefs", $r->param("browse_setdefs"));
	##### Asked to browse certain problems
        if($r->param('edit_local') || $r->param('new_local_set') 
                 || !( $r->param('next_page') || $r->param('prev_page') || $r->param('lib_view') || $r->param('lib_view_bpl') || $r->param('lib_view_bplen') || $r->param('lib_view_spcf') || $r->param('view_setdef_set') || $r->param('view_mysets_set') || $r->param('view_local_set')) 
               ) {
	    $use_previous_problems = 0; @pg_files = (); ## clear old problems
        }
	if ($browse_lib ne '') {
		$browse_which = $browse_lib;
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_bpl_library')) {
		$browse_which = 'browse_bpl_library';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
        } elsif ($r->param('browse_bplen_library')) {
		$browse_which = 'browse_bplen_library';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_spcf_library')) {
		$browse_which = 'browse_spcf_library';
		$self->{current_library_set} = "browse_setdefs";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_npl_library')) {
		$browse_which = 'browse_npl_library';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_local')) {
		$browse_which = 'browse_local';
		#$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_mysets')) {
		$browse_which = 'browse_mysets';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_setdefs')) {
		$browse_which = 'browse_setdefs';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems

		##### Change the seed value

	} elsif ($r->param('rerandomize')) {
		$self->{problem_seed}= 1+$self->{problem_seed};
		#$r->param('problem_seed', $problem_seed);
		$self->addbadmessage($r->maketext('Changing the problem seed for display, but there are no problems showing.')) if $none_shown;

		##### Clear the display

	} elsif ($r->param('cleardisplay')) {
		@pg_files = ();
		$use_previous_problems=0;
		$self->addbadmessage($r->maketext('The display was already cleared.')) if $none_shown;

		##### View problems selected from the local list

	} elsif ($r->param('view_local_set')) {
		$r->{showHints} = 1;
		$r->{showSolutions} = 1;
				
		my $set_to_display = $self->{current_library_set};
		if (not defined($set_to_display) or $set_to_display eq $r->maketext(SELECT_LOCAL_STRING) or $set_to_display eq "Found no directories containing problems") {
			$self->addbadmessage($r->maketext('You need to select a set to view.'));
		} else {
			$set_to_display = '.' if $set_to_display eq $r->maketext(MY_PROBLEMS);
			$set_to_display = substr($browse_which,7) if $set_to_display eq $r->maketext(MAIN_PROBLEMS);
			@pg_files = list_pg_files($ce->{courseDirs}->{templates},
				"$set_to_display");
			@pg_files = map {{'filepath'=> $_, 'morelt'=>0}} @pg_files;
			$use_previous_problems=0;
		}

		##### View problems selected from the a set in this course

	} elsif ($r->param('view_mysets_set')) {
		$r->{showHints} = 1;
		$r->{showSolutions} = 1;
				
		my $set_to_display = $self->{current_library_set};
		debug("set_to_display is $set_to_display");
		if (not defined($set_to_display) 
				or $set_to_display eq $r->maketext(SELECT_HMW_SET_STRING)
				or $set_to_display eq $r->maketext(NO_LOCAL_SET_STRING)) {
			$self->addbadmessage($r->maketext("You need to select a set from this course to view."));
		} else {
			# DBFIXME don't use ID list, use an iterator
			my @problemList = $db->listGlobalProblems($set_to_display);
			my $problem;
			@pg_files=();
			for $problem (@problemList) {
				my $problemRecord = $db->getGlobalProblem($set_to_display, $problem); # checked
				die "global $problem for set $set_to_display not found." unless
					$problemRecord;
				push @pg_files, $problemRecord->source_file;

			}
			# Don't sort, leave them in the order they appeared in the set
			#@pg_files = sortByName(undef,@pg_files);
			@pg_files = map {{'filepath'=> $_, 'morelt'=>0}} @pg_files;
			$use_previous_problems=0;
		}

		##### View from the library database
 
	} elsif ($r->param('lib_view')) {
 
		@pg_files=();
		my $typ = "";
		$r->{showHints} = 1;
		$r->{showSolutions} = 1;
		my @dbsearch = WeBWorK::Utils::ListingDB::getSectionListings($r, $typ);
		@pg_files = process_search($r, $typ, @dbsearch);
		$use_previous_problems=0;

		##### View a set from a bpl database

	} elsif ($r->param('lib_view_bpl')) {
 
		@pg_files=();
                my $typ = "";

                $typ = 'BPL';
                $r->{showHints} = 1;
                $r->{showSolutions} = 1;
                
               
                my @dbsearch = WeBWorK::Utils::ListingDB::getBPLDBListings($r,0, $typ);

		@pg_files = process_search($r,$typ, @dbsearch);
		$use_previous_problems=0;

		##### View a set from a english bpl database

	} elsif ($r->param('lib_view_bplen')) {
 
		@pg_files=();
                my $typ = "";

                $typ = 'BPLEN';
                $r->{showHints} = 1;
                $r->{showSolutions} = 1;
                
               
                my @dbsearch = WeBWorK::Utils::ListingDB::getBPLENDBListings($r,0, $typ);

		@pg_files = process_search($r,$typ, @dbsearch);
		$use_previous_problems=0;

		##### View a set from specific libraries

	} elsif ($r->param('lib_view_spcf')) {
 
		@pg_files=();
                my $typ = '';
                if($r->param('bbrowse_which') eq 'browse_spcf_library') {
                   $r->{showHints} = 1;
                   $r->{showSolutions} = 1;
                }
               

		my @dbsearch = WeBWorK::Utils::ListingDB::getDirListings($r, $typ);
		@pg_files = process_search($r,$typ, @dbsearch);
		$use_previous_problems=0;

		##### View a set from a set*.def

	} elsif ($r->param('view_setdef_set')) {

		$r->{showHints} = 1;
		$r->{showSolutions} = 1;
				 
		my $set_to_display = $self->{current_library_set};
		debug("set_to_display is $set_to_display");
		if (not defined($set_to_display) 
				or $set_to_display eq $r->maketext(SELECT_SETDEF_FILE_STRING)
				or $set_to_display eq $r->maketext(NO_LOCAL_SET_STRING)) {
			$self->addbadmessage($r->maketext("You need to select a set definition file to view."));
		} else {
			@pg_files= $self->read_set_def($set_to_display);
			@pg_files = map {{'filepath'=> $_, 'morelt'=>0}} @pg_files;
		}	
		$use_previous_problems=0; 

		##### Edit the current local homework set

	} elsif ($r->param('edit_local')) { ## Jump to set edit page

		; # already handled


		##### Make a new local homework set

	} elsif ($r->param('new_local_set')) {
		if ($r->param('new_set_name') !~ /^[\w .-]*$/) {
			$self->addbadmessage($r->maketext("The name '[_1]' is not a valid set name.  Use only letters, digits, -, _, and .",$r->param('new_set_name')));
		} else {
			my $newSetName = $r->param('new_set_name');
			# if we want to munge the input set name, do it here
			$newSetName =~ s/\s/_/g;
			debug("local_sets was ", $r->param('local_sets'));
			$r->param('local_sets',$newSetName);  ## use of two parameter param
			debug("new value of local_sets is ", $r->param('local_sets'));
			my $newSetRecord	 = $db->getGlobalSet($newSetName);
			if (! $newSetName) {
			    $self->addbadmessage($r->maketext("You did not specify a new set name."));
			} elsif (defined($newSetRecord)) {
			    $self->addbadmessage($r->maketext("The set name '[_1]' is already in use.  Pick a different name if you would like to start a new set.",$newSetName));
			} else {			# Do it!
				# DBFIXME use $db->newGlobalSet
				$newSetRecord = $db->{set}->{record}->new();
				$newSetRecord->set_id($newSetName);
				$newSetRecord->set_header("defaultHeader");
				$newSetRecord->hardcopy_header("defaultHeader");
				# It's convenient to set the due date two weeks from now so that it is 
				# not accidentally available to students.  
				
				my $dueDate = time+2*60*60*24*7;
				my $display_tz = $ce->{siteDefaults}{timezone};
				my $fDueDate = $self->formatDateTime($dueDate, $display_tz, "%m/%d/%Y at %I:%M%P");
				my $dueTime = $ce->{pg}{timeAssignDue};
				
				# We replace the due time by the one from the config variable
				# and try to bring it back to unix time if possible
				$fDueDate =~ s/\d\d:\d\d(am|pm|AM|PM)/$dueTime/;
				
				$dueDate = $self->parseDateTime($fDueDate, $display_tz);
				$newSetRecord->open_date($dueDate - 60*$ce->{pg}{assignOpenPriorToDue});
				$newSetRecord->due_date($dueDate);
				$newSetRecord->answer_date($dueDate + 60*$ce->{pg}{answersOpenAfterDueDate});	
				
				$newSetRecord->visible(1);
				$newSetRecord->enable_reduced_scoring(0);
				$newSetRecord->assignment_type('default');
				eval {$db->addGlobalSet($newSetRecord)};
				if ($@) {
					$self->addbadmessage("Problem creating set $newSetName<br> $@");
				} else {
					$self->addgoodmessage($r->maketext("Set [_1] has been created.", $newSetName));
					my $selfassign = $r->param('selfassign') || "";
					$selfassign = "" if($selfassign =~ /false/i); # deal with javascript false
					if($selfassign) {
						$self->assignSetToUser($userName, $newSetRecord);
						$self->addgoodmessage($r->maketext("Set [_1] was assigned to [_2]", $newSetName,$userName));
					}
				}
			}
		}

	} elsif ($r->param('next_page')) {
		# Can set first/last problem, but not index yet
		$first_index = $last_index+1;
		my $oli = 0;
		my $cnt = 0;
		while(($oli = next_prob_group($last_index, @all_past_list)) != -1 and $cnt<$maxShown) {
			$cnt++;
			$last_index = $oli;
		}
		$last_index = end_prob_group($last_index, @all_past_list);
	} elsif ($r->param('prev_page')) {
		# Can set first/last index, but not problem yet
		$last_index = $first_index-1; 
		my $oli = 0;
		my $cnt = 0;
		while(($oli = prev_prob_group($first_index, @all_past_list)) != -1 and $cnt<$maxShown) {
			$cnt++;
			$first_index = $oli;
		}
		$first_index = 0 if($first_index<0);

	#} elsif ($r->param('select_all')) {
		#;
	} elsif ($r->param('library_basic')) {
		$library_basic = 1;
		for my $jj (qw(textchapter textsection textbook)) {
			$r->param('library_'.$jj,'');
		}
	} elsif ($r->param('library_advanced')) {
		$library_basic = 2;
	} elsif ($r->param('library_reset')) {
		for my $jj (qw(chapters sections subjects textbook keywords)) {
			$r->param('library_'.$jj,'');
		}
	#} elsif ($r->param('select_none')) {
	#	;
	} else {
		##### No action requested, probably our first time here
		;
	}				##### end of the if elsif ...

 
	############# List of local sets

	# DBFIXME sorting in database, please!
	my @all_db_sets = $db->listGlobalSets;
	@all_db_sets = sortByName(undef, @all_db_sets);

	if ($use_previous_problems) {
		@pg_files = @all_past_list;
		$first_shown = 0;
		$last_shown = 0;
		my ($oli, $cnt) = (0,0);
		while($oli < $first_index and ($oli = next_prob_group($first_shown, @pg_files)) != -1) {
			$cnt++;
			$first_shown = $oli;
		}
		$first_shown = $cnt;
		$last_shown = $oli;
		while($oli <= $last_index and $oli != -1) {
			$oli = next_prob_group($last_shown, @pg_files);
			$cnt++;
			$last_shown = $oli;
		}
		$last_shown = $cnt-1;
		$total_probs = $count;
	} else {
		### Main place to set first/last shown for new problems
		$first_shown = 0;
		$first_index = 0;
		$last_index = 0;
		$last_shown = 1;
		$total_probs = 0;
		my $oli = 0;
		while(($oli = next_prob_group($last_index, @pg_files)) != -1 and $last_shown<$maxShown) {
			$last_shown++;
			$last_index = $oli;
		}
		$total_probs = $last_shown;
		# $last_index points to start of last group
		$last_shown--; # first_shown = 0
		$last_index = end_prob_group($last_index, @pg_files);
		$oli = $last_index;
		while(($oli = next_prob_group($oli, @pg_files)) != -1) {
			$total_probs++;
		}
	}


        my $library_stats_handler = '';
	
	if ($ce->{problemLibrary}{showLibraryGlobalStats} ||
	   $ce->{problemLibrary}{showLibraryLocalStats} ) {
	    $library_stats_handler = WeBWorK::Utils::LibraryStats->new($ce);
	}

	############# Now store data in self for retreival by body
	$self->{browse_which} = $browse_which;
	$self->{first_shown} = $first_shown;
	$self->{last_shown} = $last_shown;
	$self->{first_index} = $first_index;
	$self->{last_index} = $last_index;
	$self->{total_probs} = $total_probs;
	$self->{pg_files} = \@pg_files;
	$self->{all_db_sets} = \@all_db_sets;
	$self->{library_basic} = $library_basic;
	$self->{library_stats_handler} = $library_stats_handler; 
}


sub title {
	my ($self) = @_;
	return $self->r->maketext("Library Browser");
}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $ce = $r->ce;		# course environment
	my $db = $r->db;		# database
	my $j;			# garden variety counter

	my $courseID = $self->r->urlpath->arg("courseID");
	my $userName = $r->param('user');

	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;

	### Check that this is a professor
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		print "User $userName returned " . 
			$authz->hasPermissions($userName, "modify_problem_sets") . 
	" for permission";
		return(CGI::div({class=>'ResultsWithError'},
		CGI::em("You are not authorized to access the Instructor tools.")));
	}

	my $showHints = 1;
	my $showSolutions = 1;

	##########	Extract information computed in pre_header_initialize

	my $first_shown = $self->{first_shown};
	my $last_shown = $self->{last_shown}; 
	my $first_index = $self->{first_index};
	my $last_index = $self->{last_index}; 
	my $total_probs = $self->{total_probs}; 
	my $browse_which = $self->{browse_which};
	my $problem_seed = $self->{problem_seed}||1234;
	my @pg_files = @{$self->{pg_files}};
	my @all_db_sets = @{$self->{all_db_sets}};

	my @plist = map {$_->{filepath}} @pg_files[$first_index..$last_index];

	my %isInSet;
	my $setName = $r->param("local_sets");
	if ($setName) {
		# DBFIXME where clause, iterator
		# DBFIXME maybe instead of hashing here, query when checking source files?
		# DBFIXME definitely don't need to be making full record objects
		# DBFIXME SELECT source_file FROM whatever_problem WHERE set_id=? GROUP BY source_file ORDER BY NULL;
		# DBFIXME (and stick result directly into hash)
		foreach my $problem ($db->listGlobalProblems($setName)) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem);
			$isInSet{$problemRecord->source_file} = 1;
		}
	}
	$self->{isInSet} = \%isInSet;

	##########	Top part
	my $webwork_htdocs_url = $ce->{webwork_htdocs_url};
	print CGI::start_form({-method=>"POST", -action=>$r->uri, -name=>'mainform', -id=>'mainform'}),
		$self->hidden_authen_fields,
                CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseID }),
			'<div id="ShowResults" align="center">';
	print CGI::hidden(-name=>'bbrowse_which', -value=>$browse_which,-override=>1),
		CGI::hidden(-name=>'problem_seed', -value=>$problem_seed, -override=>1);
	for ($j = 0 ; $j < scalar(@pg_files) ; $j++) {
		print CGI::hidden(-name=>"all_past_list$j", -value=>$pg_files[$j]->{filepath}, -override=>1)."\n";
		print CGI::hidden(-name=>"all_past_mlt$j", -value=>($pg_files[$j]->{morelt} || 0), -override=>1)."\n";
	}

	print CGI::hidden(-name=>'first_shown', -value=>$first_shown,-override=>1);
	
	print CGI::hidden(-name=>'last_shown', -value=>$last_shown, -override=>1);
	print CGI::hidden(-name=>'first_index', -value=>$first_index);
	print CGI::hidden(-name=>'last_index', -value=>$last_index);
	print CGI::hidden(-name=>'total_probs', -value=>$total_probs);

	print CGI::start_table({class=>"library-browser-table"});
	$self->make_top_row('all_db_sets'=>\@all_db_sets, 'browse_which'=> $browse_which);

	########## Now print problems
	my ($jj,$mltnumleft)=(0,-1);
	for ($jj=0; $jj<scalar(@plist); $jj++) {
		$pg_files[$jj+$first_index]->{filepath} =~ s|^$ce->{courseDirs}->{templates}/?||;
		# For MLT boxes, need to know if we are at the end of a group
		# make_data_row can't figure this out since it only sees one file
		$mltnumleft--;
		my $sourceFileData = $pg_files[$jj+$first_index];
		$self->make_data_row($sourceFileData, $plist[$jj], $jj+1,$mltnumleft);
		$mltnumleft = scalar(@{$sourceFileData->{children}}) if($sourceFileData->{children});
	}

	########## Finish things off
	print CGI::end_table();
	print '</div>';
	#	 if($first_shown>0 or (1+$last_shown)<scalar(@pg_files)) {
	my ($next_button, $prev_button) = ("", "");
        my $c = 0;
        if($browse_which eq 'browse_bplen_library') {
           $c = 1;
        }
        if($browse_which eq 'browse_spcf_library') {
           $c = 6;
        }
        if($browse_which eq 'browse_npl_library') {
           $c = 2;
        }
        if($browse_which eq 'browse_local') {
           $c = 3;
        }
        if($browse_which eq 'browse_mysets') {
           $c = 4;
        }
        if($browse_which eq 'browse_setdefs') {
           $c = 5;
        }

	if ($first_index > 0) {
		$prev_button = CGI::submit(-name=>"prev_page", -style=>"width:18ex",
						 -value=>$r->maketext("Previous page")
						 );
	}
	if ((1+$last_index)<scalar(@pg_files)) {
		$next_button = CGI::submit(-name=>"next_page", -style=>"width:18ex",
						 -value=>$r->maketext("Next page")
						 );
	}
	if (scalar(@pg_files)>0) {
		print "<div id='showResultsEnd'>\n";
		print CGI::p(CGI::span({-id=>'what_shown'}, CGI::span({-id=>'firstshown'}, $first_shown+1)."-".CGI::span({-id=>'lastshown'}, $last_shown+1))." ".$r->maketext("of")." ".CGI::span({-id=>'totalshown'}, $total_probs).
			" ".$r->maketext("shown").".", $prev_button, " ", $next_button,
		);
		print "</div>";
		#print CGI::p($r->maketext('Some problems shown above represent multiple similar problems from the database.  If the (top) information line for a problem has a letter M for "More", hover your mouse over the M  to see how many similar problems are hidden, or click on the M to see the problems.  If you click to view these problems, the M becomes an L, which can be clicked on to hide the problems again.'));
	}
	#	 }
	print CGI::end_form(), "\n";

	return "";	
}

sub output_JS {
	my ($self) = @_;
	my $ce = $self->r->ce;
	my $webwork_htdocs_url = $ce->{webwork_htdocs_url};


	# This is for translation of js files
	my $lang = $ce->{language};

	print CGI::start_script({type=>"text/javascript"});
	print "localize_basepath = \"$webwork_htdocs_url/js/i18n/\";";
	print "lang = \"$lang\";";
	print CGI::end_script();
	
	print qq!<script src="$webwork_htdocs_url/js/i18n/localize.js"></script>!;
	print qq!<script src="$webwork_htdocs_url/js/vendor/jquery/modules/jquery.ui.touch-punch.js"></script>!;
	print qq!<script src="$webwork_htdocs_url/js/vendor/jquery/modules/jquery.watermark.min.js"></script>!;
	print qq!<script src="$webwork_htdocs_url/js/vendor/underscore/underscore.js"></script>!;
	print qq!<script src="$webwork_htdocs_url/js/vendor/backbone/backbone.js"></script>!;
	print CGI::start_script({type=>"text/javascript", src=>"$webwork_htdocs_url/js/apps/Base64/Base64.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$webwork_htdocs_url/js/vendor/tagify/js/tagify.js"}), CGI::end_script();

	print qq{<script type="text/javascript" src="$webwork_htdocs_url/js/legacy/vendor/knowl.js"></script>};

	print qq!<script src="$webwork_htdocs_url/js/vendor/bootstrap/js/bootstrap-tagsinput.js"></script>!;
	print qq!<script src="$webwork_htdocs_url/js/apps/ImageView/imageview.js"></script>!;
	print CGI::script({ src => "$webwork_htdocs_url/node_modules/iframe-resizer/js/iframeResizer.min.js" }, "");
	print CGI::script({ src => "$webwork_htdocs_url/js/apps/ActionTabs/actiontabs.js", defer => undef }, "");
	print CGI::script({ src => "$webwork_htdocs_url/js/apps/SetMaker/setmaker.js", defer => "" }, "");
	print CGI::start_script({type=>"text/javascript", src=>"$webwork_htdocs_url/js/legacy/vendor/tabbert.js"}), CGI::end_script();
		
	if ($self->r->authz->hasPermissions(scalar($self->r->param('user')), "modify_tags")) {
		my $site_url = $ce->{webworkURLs}->{htdocs};
		print qq!<script src="$site_url/js/apps/TagWidget/tagwidget.js"></script>!;
		if (open(TAXONOMY,  $ce->{webworkDirs}{root}.'/htdocs/DATA/tagging-taxonomy.json') ) {
			my $taxo = '[]';
			$taxo = join("", <TAXONOMY>); 
			close TAXONOMY;
			print qq!\n<script>var taxo = $taxo ;</script>!;
		} else {
			print qq!\n<script>var taxo = [] ;</script>!;
			print qq!\n<script>alert('Could not load the OPL taxonomy from the server.');</script>!;
		}
	}
	return '';
}



sub output_CSS {
	my ($self) = @_;
	my $ce = $self->r->ce;
	my $webwork_htdocs_url = $ce->{webwork_htdocs_url};

	print qq!<link href="$webwork_htdocs_url/node_modules/jquery-ui-themes/themes/ui-lightness/jquery-ui.min.css" rel="stylesheet" type="text/css"/>!;

	print qq{<link href="$webwork_htdocs_url/js/apps/ImageView/imageview.css" rel="stylesheet" type="text/css" />};

	print qq{<link href="$webwork_htdocs_url/themes/math4/bpl.css" rel="stylesheet" type="text/css" />};

	print qq{<link href="$webwork_htdocs_url/js/vendor/bootstrap/css/bootstrap-tagsinput.css" rel="stylesheet" type="text/css" />};

	print qq{<link href="$webwork_htdocs_url/js/vendor/bootstrap/css/bootstrap-tagsinput-typeahead.css" rel="stylesheet" type="text/css" />};

	print qq{<link href="$webwork_htdocs_url/css/knowlstyle.css" rel="stylesheet" type="text/css" />};

	return '';

}

sub output_jquery_ui {

    return '';

}



=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.

=cut

1;
