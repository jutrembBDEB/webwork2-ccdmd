################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Hardcopy;
use base qw(WeBWorK::ContentGenerator);
my $timer1_ON = 1;

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate a PDF version of one or more
problem sets.

=cut

use strict;
use warnings;
use CGI qw();
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile makeTempDirectory);
use Apache::Constants qw(:common REDIRECT);

sub pre_header_initialize {
	my ($self, $singleSet) = @_;
	
	my $r               = $self->{r};
	my $ce              = $self->{ce};
	my $db              = $self->{db};
	my @sets            = $r->param("hcSet");
	my @users           = $r->param("hcUser");
	my $hardcopy_format = $r->param('hardcopy_format') ? $r->param('hardcopy_format') : '';
	

	# add singleSet to the list of sets
	if (length $singleSet > 0) {
		$singleSet =~ s/^set//;
		unshift @sets, $singleSet unless grep { $_ eq $singleSet } @sets;
	}
	
	# default user is the effectiveUser
	unless (@users) {
		unshift @users, $r->param("effectiveUser");
	}
	
	$self->{user}            = $db->getUser($r->param("user"));
	$self->{permissionLevel} = $db->getPermissionLevel($r->param("user"))->permission();
	$self->{effectiveUser}   = $db->getUser($r->param("effectiveUser"));
	$self->{sets}            = \@sets;
	$self->{users}           = \@users;
	$self->{hardcopy_format} = $hardcopy_format;
	$self->{errors}          = [];
	$self->{warnings}        = [];
	
	# security checks
	my $multiSet    = $self->{permissionLevel} > 0;
	my $multiUser   = $self->{permissionLevel} > 0;
	
	if (@sets > 1 and not $multiSet) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for multiple sets. Please select a single set and try again."];
	}
	if (@users > 1 and not $multiUser) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for multiple users. Please select a single user and try again."];
	}
	if ($users[0] ne $self->{effectiveUser}->user_id and not $multiUser) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for other users."];
	}
	
	unless ($self->{generationError}) {
		if ($r->param("generateHardcopy")) {
#			my ($tempDir, $fileName) = eval { $self->generateHardcopy() };
			my ($pdfFileURL) = eval { $self->generateHardcopy() };
			
			$self->{generationError} = $@ if $@;
# 			warn "pdfFileURL is $pdfFileURL";
# 			warn "generation error is ".$self->{generationError};
# 			warn "hardcopy_format is ".$self->{hardcopy_format};
			if ( $self->{generationError}  ) {
				
				# In this case no correct pdf file was generated.
				# throw the error up higher.
				# The error is reported in body.
				# the tempDir was removed in generateHardcopy
			} elsif ( $self->{hardcopy_format} eq 'tex')   {
				# Only tex output was asked for, proceed to have the tex output handled by the subroutine
				# "body".
				
			} else {
			    # information for redirect
			    	$self->{pdfFileURL} = $pdfFileURL;
			}
		}
	}
}

sub header {
	my ($self) = @_;
	my $r = $self->{r};
	
	if (exists $self->{pdfFileURL}) {
 		$r->header_out(Location => $self->{pdfFileURL} );
		$self->{noContent} = 1;
 		return REDIRECT;
	}
	$r->content_type("text/html");
	$r->send_http_header();
}

# -----

sub path {
	my ($self, undef, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"Hardcopy Generator" => "",
	);
}

sub title {
	return "Hardcopy Generator";
}

sub body {
	my $self = shift;
	
	if ($self->{generationError}) {
		if (ref $self->{generationError} eq "ARRAY") {
			my ($disposition, @rest) = @{$self->{generationError}};
			if ($disposition eq "PGFAIL") {
				$self->multiErrorOutput(@{$self->{errors}});
				return "";
			} elsif ($disposition eq "FAIL") {
				print $self->errorOutput(@rest);
				return "";
			} elsif ($disposition eq "RETRY") {
				print $self->errorOutput(@rest);
			} else { # a "simple" error
				print CGI::p(CGI::font({-color=>"red"}, @rest));
			}
		} else {
			# not something we were expecting...
			die $self->{generationError};
		}
	}
	if (@{$self->{warnings}}) {
		# FIXME: this code will only be reached if there was also a
		# generation error, because otherwise the module will send
		# the PDF instead. DAMN!
		$self->multiWarningOutput(@{$self->{warnings}});
	}
	if ($self->{hardcopy_format} eq 'tex') {
	
		my $r_tex_content = $self->{r_tex_content};
		return $$r_tex_content;
	
	
	}
	$self->displayForm();
}

sub multiErrorOutput($@) {
	my ($self, @errors) = @_;
	
	print CGI::h2("Compile Errors");
	print CGI::p(<<EOF);
WeBWorK has encountered one or more  errors while attempting to process
these problem sets. It is likely that there are errors in the problems
themselves. If you are a student, contact your professor to have the errors
corrected. If you are a professor, please consult the error output below for
more information.
EOF
	foreach my $error (@errors) {
	    my $user = $error->{user};
	    my $userName = $user->user_id . ' ('.$user->first_name.' '.$user->last_name. ')';
		print CGI::h3("Set: ", $error->{set}, ", Problem: ", $error->{problem}, "for $userName");
		print CGI::h4("Error messages"), CGI::blockquote(CGI::pre($error->{message}));
		print CGI::h4("Error context"), CGI::blockquote(CGI::pre($error->{context}));
	}
}

sub multiWarningOutput($@) {
	my ($self, @warnings) = @_;
	
	print CGI::h2("Software Warnings");
	print CGI::p(<<EOF);
WeBWorK has encountered one or more warnings while attempting to process these
problem sets. It is likely that this indicates errors or ambiguitiees in the
problems themselves. If you are a student, contact your professor to have the
problems corrected. If you are a professor, please consut the warning output
below for more informaiton.
EOF
	foreach my $warning (@warnings) {
		print CGI::h3("Set: ", $warning->{set}, ", Problem: ", $warning->{problem});
		print CGI::h4("Error messages"), CGI::blockquote(CGI::pre($warning->{message}));
	}
}

# -----

sub displayForm($) {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	
	print CGI::start_p(), "Select the problem sets for which to generate hardcopy versions.";
	if ($self->{permissionLevel} > 0) {
		print "You may also select multiple users from the users list. You will receive hardcopy for each (set, user) pair.";
	}
	print CGI::end_p();
	
	my $download_texQ = $self->{permissionLevel} > 0;
	
	#  ##########construct action URL #################
	my $ce         = $self->{ce};
	my $root       = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $actionURL  = "$root/$courseName/hardcopy/";
	#  ################################################
	
	print CGI::start_form(-method=>"POST", -action=>$actionURL);
	print $self->hidden_authen_fields();
	print CGI::h3("Options");
	print CGI::p("You may choose to show any of the following data. Correct answers and solutions are only available to privileged users or after the answer date of the problem set.");
	print CGI::p(
		CGI::checkbox(
			-name    => "showCorrectAnswers",
			-checked => $r->param("showCorrectAnswers") || 0,
			-label   => "Correct answers",
		), CGI::br(),
		CGI::checkbox(
			-name    => "showHints",
			-checked => $r->param("showHints") || 0,
			-label   => "Hints",
		), CGI::br(),
		CGI::checkbox(
			-name    => "showSolutions",
			-checked => $r->param("showSolutions") || 0,
			-label   => "Solutions",
		),
	);
	print CGI::start_table({-width=>"100%"}), CGI::start_Tr({-valign=>"top"});
	
	my $multiSet          = $self->{permissionLevel} > 0;
	my $multiUser         = $self->{permissionLevel} > 0;
	my $preOpenSets       = $self->{permissionLevel} > 0;
	my $effectiveUserName = $self->{effectiveUser}->user_id;	
	my @setNames     = $db->listUserSets($effectiveUserName);
	my @sets         = $db->getMergedSets( map { [$effectiveUserName, $_] }  @setNames );
	@sets            = sort { $a->set_id cmp $b->set_id } @sets;
	@setNames        = map( {$_->set_id } @sets );  # get sorted version of setNames
	my %setLabels    = map( {($_->set_id, "set ".$_->set_id )} @sets );
	my (@users, @userNames,%userLabels);
	
	if ($multiUser) {
		@userNames    = $self->{db}->listUsers();
		@users        = $self->{db}->getUsers(@userNames);
		@users        = sort { $a->last_name cmp $b->last_name } @users;
		@userNames    = map( {$_->user_id} @users );  # get sorted version of user names
		%userLabels   = map( {($_->user_id , $_->last_name .", ". $_->first_name ." --- ". $_->user_id   ) } @users ); 
	}
	# set selection menu
	{
		print CGI::start_td();
		print CGI::h3("Sets");
# 		print CGI::start_table();
# 		foreach my $set (@sets) {
# 			my $checked = grep { $_ eq $set->set_id } @{$self->{sets}};
# 			my $control;
# 			if (time < $set->open_date and not $preOpenSets) {
# 				$control = "";
# 			} else {
# 				if ($multiSet) {
# 					$control = CGI::checkbox(
# 						-name=>"hcSet",
# 						-value=>$set->set_id,
# 						-label=>"",
# 						-checked=>$checked
# 					);
# 				} else {
# 					$control = CGI::radio_group(
# 						-name=>"hcSet",
# 						-values=>[$set->set_id],
# 						-default=>($checked ? $set->set_id : "-"),
# 						-labels=>{$set->set_id => ""}
# 					);
# 				}
# 			}
# 			print CGI::Tr(CGI::td([
# 				$control,
# 				$set->set_id,
# 			]));
# 		}
# 		print CGI::end_table();
		print CGI::scrolling_list(-name=>'hcSet',
							   -values=>\@setNames,
							   -labels=>\%setLabels,
							   -size  => 10,
							   -multiple => $multiSet,
							   -defaults => $self->{sets},					 
		);	 
		print CGI::end_td();
	}
	
	# user selection menu
	if ($multiUser) {
		print CGI::start_td();
		print CGI::h3("Users");
		#print CGI::start_table();
		#print CGI::Tr(
		#	CGI::td(CGI::checkbox(-name=>"hcAllUsers", -value=>"1", -label=>"")),
		#	CGI::td({-colspan=>"2"}, "All Users"),
		#);
		#print CGI::Tr(CGI::td({-colspan=>"3"}, "&nbsp;"));


		# foreach my $user (@users) {
# 			my $checked = grep { $_ eq $user->user_id } @{$self->{users}};
# 			print CGI::Tr(CGI::td([
# 				CGI::checkbox(-name=>"hcUser", -value=>$user->user_id, -label=>"", -checked=>$checked),
# 				$user->user_id,
# 				$user->last_name.", ".$user->first_name,
# 			]));
# 		}
# 
# 		print CGI::end_table();
		print CGI::scrolling_list(-name=>'hcUser',
							   -values=>\@userNames,
							   -labels=>\%userLabels,
							   -size  => 10,
							   -multiple => 'true',
							   -defaults => $self->{users},
		);
		print CGI::end_td();
	}
	
	print CGI::end_Tr(), CGI::end_table();
	if ($download_texQ) {  # provide choice of pdf or tex output 
		print CGI::p( {-align => "center"},
				CGI::radio_group(
							-name=>"hardcopy_format",
							-values=>['pdf', 'tex'],
							-default=>'pdf',
							-labels=>{'tex'=>'TeX','pdf'=>'PDF'}
				),
		);
	} else {   # only pdf output available
		print CGI::hidden(-name=>'hardcopy_format',-value=>'pdf');
	}
	print CGI::p({-align=>"center"},
		CGI::submit(-name=>"generateHardcopy", -label=>"Generate Hardcopy"));
	print CGI::end_form();
	
	return "";
}

sub generateHardcopy($) {
	my $self = shift;
	my $ce = $self->{ce};
	my @sets = @{$self->{sets}};
	my @users = @{$self->{users}};
	my $multiSet = $self->{permissionLevel} > 0;
	my $multiUser = $self->{permissionLevel} > 0;
	# sanity checks
	unless (@sets) {
		die ["RETRY", "No sets were specified."];
	}
	unless (@users) {
		die ["RETRY", "No users were specified."];
	}
	
	# determine where hardcopy is going to go
	my $tempDir = makeTempDirectory($ce->{webworkDirs}->{tmp}, "webwork-hardcopy");
	
	# determine name of PDF file  #FIXME it might be best to have the effective user in here somewhere
	my $courseName = $self->{ce}->{courseName};
	my $fileNameSet = (@sets > 1 ? "multiset" : $sets[0]);
	my $fileNameUser = (@users > 1 ? "multiuser" : $users[0]);
	my $fileName = "$courseName.$fileNameUser.$fileNameSet.pdf";
	
	# for each user ... generate TeX for each set
	my $tex;
	#
	# the document tex preamble
	$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{preamble});
	# separate users by page break, or something
	foreach my $user (@users) {
		$tex .=  $self->getMultiSetTeX($user, @sets);
	    if (@users) {
			# separate users, but not after the last set
			$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{userDivider});
		}
		
	}
	# the document postamble
	$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{postamble});
	
	# deal with PG errors
	if (@{$self->{errors}}) {
		die ["PGFAIL"];
	}
	
	# FIXME: add something like:
	#if (@{$self->{warnings}}) {
	#	$self->{generationWarnings} = 1;
	#}
	# ???????
	
	# "try" to generate pdf or return TeX file
	my $pdfFileURL = undef;
	if ($self->{hardcopy_format} eq 'pdf' ) {
		my $errors = '';
		$pdfFileURL = eval { $self->latex2pdf($tex, $tempDir, $fileName) };
		if ($@) {
			$errors = $@;
			#$errors =~ s/\n/<br>/g;  # make this readable on HTML FIXME make this a Utils. filter (Error2HTML)
			# clean up temp directory
			# FIXME this clean up done in latex2pdf?  rmtree($tempDir);
			die ["FAIL", "Failed to generate PDF from tex", $errors]; #throw error to subroutine body	
		} else {
		    # pass the relative temp file path back up to go subroutine 
		    # to have an appropriate redirect generated.
		
		
		}
	} elsif ($self->{hardcopy_format} eq 'tex')    {
	    $tex = protect_HTML($tex);
	    #$tex =~ s/\n/\<br\>\n/g;
	    $tex = join('', ("<pre>\n",$tex,"\n</pre>\n"));
		$self->{r_tex_content} = \$tex;
		
	
	} else {
	
	
		die["FAIL", "Hard copy format |".$self->{hardcopy_format}. "| not recognized."];
	
	}
	#return $tempDir, $fileName;
	# return $pdfFilePath;
	return $pdfFileURL;
}

# -----

sub latex2pdf {
	# this is a little ad-hoc function which I will replace with a LaTeX
	# module at some point (or put it in Utils).
	my ($self, $tex, $tempDir, $fileName) = @_;
	my $finalFile = "$tempDir/$fileName";
	my $ce = $self->{ce};
	
	# Location for hardcopy file to be downloaded
	# FIXME  this should use surePathToTmpFile
	my $hardcopyTempDirectory = $ce->{courseDirs}->{html_temp}."/hardcopy";
	mkdir ($hardcopyTempDirectory)  or die "Unable to make $hardcopyTempDirectory" unless -e $hardcopyTempDirectory;
	my $hardcopyFilePath        =  "$hardcopyTempDirectory/$fileName";
	my $hardcopyFileURL         =  $ce->{courseURLs}->{html_temp}."/hardcopy/$fileName";
	$self->{hardcopyFilePath}   =  $hardcopyFilePath;
	$self->{hardcopyFileURL}    =  $hardcopyFileURL;
	
	## create a temporary directory for tex to shit in
	# - we're using the existing temp dir. now
	
	my $wd = $tempDir;
	my $texFile = "$wd/hardcopy.tex";
	my $pdfFile = "$wd/hardcopy.pdf";
	my $logFile = "$wd/hardcopy.log";
	
	# write the tex file
	local *TEX;
	open TEX, ">", $texFile or die "Failed to open $texFile: $!\n".CGI::br();
	print TEX $tex;
	close TEX;
	
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex = $ce->{externalPrograms}->{pdflatex};
	my $pdflatexResult = system "cd $wd && $pdflatex $texFile";	
	
	# Even with errors there may be a valid pdfFile.  Move it to where we can get it.
	if (-e $pdfFile) {

       # moving to course tmp/hardcopy directory
	    system "/bin/mv", $pdfFile, $hardcopyFilePath  
			and die "Failed to mv: $pdfFile to  $hardcopyFilePath<br> Quite likely this means that there ".
			        "is not sufficient write permission for some directory.<br>$!\n".CGI::br(); 
	}
	# Alert the world that the tex file did not process perfectly.
	if ($pdflatexResult) {
		# something bad happened
		my $textErrorMessage = "Call to $pdflatex failed: $!\n".CGI::br();
		
		if (-e $hardcopyFilePath ) {
			 # FIXME  Misuse of html tags!!!
			$textErrorMessage.= "<h4>Some pdf output was produced and is available ". CGI::a({-href=>$hardcopyFileURL},"here.</h4>").CGI::hr();
		}
		# report logfile
		if (-e $logFile) {
			$textErrorMessage .= "pdflatex ran, but did not succeed. This suggests an error in the TeX\n".CGI::br();
			$textErrorMessage .= "version of one of the problems, or a problem with the pdflatex system.\n".CGI::br();
			my $logFileContents = eval { readTexErrorLog($logFile) };
			$logFileContents    .=  CGI::hr().CGI::hr();
			$logFileContents    .= eval { formatTexFile($texFile)     };
			if ($@) {
				$textErrorMessage .= "Additionally, the pdflatex log file could not be read, though it exists.\n".CGI::br();
			} else {
				$textErrorMessage .= "The essential contents of the TeX log are as follows:\n".CGI::hr().CGI::br();
				$textErrorMessage .= "$logFileContents\n".CGI::br().CGI::br();
			}
		} else {
			$textErrorMessage .= "No log file was created, suggesting that pdflatex never ran. Check the WeBWorK\n".CGI::br();
			$textErrorMessage .= "configuration to ensure that the path to pdflatex is correct.\n".CGI::br();
		}
		die $textErrorMessage;
	}
	

	
	## remove temporary directory
	rmtree($wd, 0, 0);

	
	-e $hardcopyFilePath or die "Failed to create $finalFile for no apparent reason.\n";
	# return hardcopyFilePath;
	return $hardcopyFileURL;
}

# -----
# FIXME move to Utils? probably not

sub readTexErrorLog {
	my $filePath = shift;
	my $print_error_switch = 0;
	my $line='';
	my @message=();
	#local($/ ) = "\n";
    open(LOGFILE,"<$filePath") or die "Can't read $filePath";
    while (<LOGFILE>) {
	    $line = $_;
	    $print_error_switch = 1  if $line =~ /^!/;  # after a fatal error start printing messages
		push(@message, protect_HTML($line)) if $print_error_switch;
    }
    close(LOGFILE);
    join("<br>\n",@message);
}

sub formatTexFile {
	my $texFilePath   = shift;
    open (TEXFILE, "$texFilePath")
	               or die "Can't open tex source file: path= $texFilePath: $!";
	
	my @message       = ();
    push @message, '<BR>\n<h3>TeX Source File:</h3><BR>\n',     ;
 
    my $lineNumber    = 1;
    while (<TEXFILE>) {
		push @message, protect_HTML("$lineNumber $_")."\n";
        $lineNumber++;
    }
    close(TEXFILE);
    #push @message, '</pre>';
    join("<br>\n",@message);
}
sub protect_HTML {
	my $line = shift;
	chomp($line);
	$line =~s/\&/&amp;/g;
	$line =~s/</&lt;/g;
	$line =~s/>/&gt;/g;
	$line;
}
sub texBlockComment(@) { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

sub getMultiSetTeX {
	my ($self, $effectiveUserName,@sets) = @_;
	my $ce = $self->{ce};
	my $tex = "";
	
	
	
	while (defined (my $setName = shift @sets)) {
		$tex .= $self->getSetTeX($effectiveUserName, $setName);
		if (@sets) {
			# divide sets, but not after the last set
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{setDivider});
		}
	}
	

	
	return $tex;
}

sub getSetTeX {
	my ($self, $effectiveUserName,$setName) = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	# FIXME (debug code line next)
	# print STDERR "Creating set $setName for $effectiveUserName \n";
	
	# FIXME We could define a default for the effective user if no correct name is passed in.
	# I'm not sure that it is wise.
	my $effectiveUser = $db->getUser($effectiveUserName);
	
	my @problemNumbers = sort { $a <=> $b }
		$db->listUserProblems($effectiveUserName, $setName);
	
	# get header and footer
	my $set       = $db->getMergedSet($effectiveUserName, $setName);
	my $setHeader = (ref($set) && $set->set_header) ? $set->set_header : $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	# database doesn't support the following yet :(
	#my $setFooter = $wwdb->getMergedSet($effectiveUserName, $setName)->set_footer
	#	|| $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	# so we don't allow per-set customization, which is probably okay :)
	my $setFooter = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	
	my $tex = "";
	
	# render header
	$tex .= texBlockComment("BEGIN $setName : $setHeader");
	$tex .= $self->getProblemTeX($effectiveUser,$setName, 0, $setHeader);
	
	# render each problem
	while (my $problemNumber = shift @problemNumbers) {
		$tex .= texBlockComment("BEGIN $setName : $problemNumber");
		$tex .= $self->getProblemTeX($effectiveUser,$setName, $problemNumber);
		if (@problemNumbers) {
			# divide problems, but not after the last problem
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{problemDivider});
		}
	}
	
	# render footer
	$tex .= texBlockComment("BEGIN $setName : $setFooter");
	$tex .= $self->getProblemTeX($effectiveUser,$setName, 0, $setFooter);
	
	return $tex;
}

sub getProblemTeX {
    $WeBWorK::timer1 ->continue("hardcopy: begin processing problem") if $timer1_ON;
	my ($self, $effectiveUser, $setName, $problemNumber, $pgFile) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	# Should we provide a default user ? I think not FIXME
	
	# $effectiveUser = $self->{effectiveUser} unless defined($effectiveUser);
	my $permissionLevel = $self->{permissionLevel};
	my $set  = $db->getMergedSet($effectiveUser->user_id, $setName);
	unless (ref($set) )  {  # return error if no set is defined
		push(@{$self->{warnings}}, 
			   setName => $setName, 
			   problem => 0,
			   message => "No set $setName exists for ".$effectiveUser->first_name.' '.
	                      $effectiveUser->last_name.' ('.$effectiveUser->user_id.' )'
	    );
	    return "No set $setName for ".$effectiveUser->user_id;
	}

	my $psvn = $set->psvn();
	
	# decide what to do about problem number
	my $problem;
	if ($problemNumber) {  # problem number defined and not zero
		$problem = $db->getMergedProblem($effectiveUser->user_id, $setName, $problemNumber);
	} elsif ($pgFile) {
		$problem = WeBWorK::DB::Record::UserProblem->new(
			set_id => $set->set_id,
			problem_id => 0,
			login_id => $effectiveUser->user_id,
			source_file => $pgFile,
			# the rest of Problem's fields are not needed, i think
		);
	}
	unless (ref($problem) )  {  # return error if no problem is defined
	    $problemNumber = 'undefined problem number' unless defined($problemNumber);
	    $setName       = 'undefined set Name' unless defined($setName);
	    my $msg        = "Problem $setName/problem $problemNumber not assigned to ".
			              $effectiveUser->first_name.' '.
	                      $effectiveUser->last_name.' ('.$effectiveUser->user_id.' )';
		push(@{$self->{warnings}}, 
			   setName => $setName, 
			   problem => $problemNumber,
			   message => $msg,
	    );
	    $msg =~ s/_/\\_/;  # escape underbars to protect them from TeX FIXME--this could be more general??
	    return $msg;
	}
	# figure out if we're allowed to get solutions and call PG->new accordingly.
	my $showCorrectAnswers = $r->param("showCorrectAnswers") || 0;
	my $showHints          = $r->param("showHints") || 0;
	my $showSolutions      = $r->param("showSolutions") || 0;
	unless ($permissionLevel > 0 or time > $set->answer_date) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => "tex",
			showHints       => $showHints,
			showSolutions   => $showSolutions,
			processAnswers  => $showCorrectAnswers,
		},
	);
	
	if ($pg->{warnings} ne "") {
		push @{$self->{warnings}}, {
			set     => $setName,
			problem => $problemNumber,
			message => $pg->{warnings},
		};
	}
	
	if ($pg->{flags}->{error_flag}) {
		push @{$self->{errors}}, {
			set     => $setName,
			problem => $problemNumber,
			user    => $effectiveUser,
			message => $pg->{errors},
			context => $pg->{body_text},
		};
		# if there was an error, body_text contains
		# the error context, not TeX code FIXME (should this error context be used?)
		$pg->{body_text} = ''; #   FIXME using undef causes error unless it is caught undef;
	} else {
		# append list of correct answers to body text
		if ($showCorrectAnswers && $problemNumber != 0) {
			my $correctTeX = "Correct Answers:\\par\\begin{itemize}\n";
			foreach my $ansName (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}}) {
				my $correctAnswer = $pg->{answers}->{$ansName}->{correct_ans};
				$correctAnswer =~ s/\^/\\\^\{\}/g;
				$correctAnswer =~ s/\_/\\\_/g;
				$correctTeX .= "\\item $correctAnswer\n";
			}
			$correctTeX .= "\\end{itemize} \\par\n";
			$pg->{body_text} .= $correctTeX;
		}
	}
	$WeBWorK::timer1 ->continue("hardcopy: end processing problem") if $timer1_ON;
	return $pg->{body_text};
}

sub texInclude {
	my ($self, $texFile) = @_;
	my $tex = "";
	
	$tex .= texBlockComment("BEGIN: $texFile");
	eval {
		$tex .= readFile($texFile)
	};
	if ($@) {
		$tex .= texBlockComment($@);
	}
	
	return $tex;
}

1;
