################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/ListingDB.pm,v 1.19 2007/08/13 22:59:59 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::ListingDB;

use strict;
use DBI;
use WeBWorK::Utils qw(readDirectory sortByName);
use WeBWorK::Utils::Tags;
use File::Basename;
use WeBWorK::Debug;
use File::Find::Rule;
use Encode::Encoder qw(encoder);
use Encode qw( decode encode );

use constant LIBRARY_STRUCTURE => {
	textbook => { select => 'tbk.textbook_id,tbk.title,tbk.author,tbk.edition',
	name => 'library_textbook', where => 'tbk.textbook_id', all => 'All Textbooks'},
	textchapter => { select => 'tc.number,tc.name', name=>'library_textchapter',
	where => 'tc.name', all => 'All Chapters'},
	textsection => { select => 'ts.number,ts.name', name=>'library_textsection',
	where => 'ts.name', all => 'All Sections'},
	problem => { select => 'prob.name' },
	};

BEGIN
{
	require Exporter;
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	$VERSION		=1.0;
	@ISA		=qw(Exporter);
	@EXPORT	=qw(
	&createListing &updateListing &deleteListing &getAllChapters
	&getAllSections &searchListings &getAllListings &getSectionListings
	&getAllDBsubjects &getAllDBchapters &getAllDBsections &getDBTextbooks
	&getDBListings &countDBListings &getTables &getDBextras &getAllKeyWords &getTop20KeyWords
        &getAllKeyWords_en &getTop20KeyWords_en
        &getAllDirs &getAllSubdirs &countDirListings &getDirListings
	);
	%EXPORT_TAGS		=();
	@EXPORT_OK		=qw();
}
use vars @EXPORT_OK;

my %OPLtables = (
 dbsubject => 'OPL_DBsubject',
 dbchapter => 'OPL_DBchapter',
 dbsection => 'OPL_DBsection',
 author => 'OPL_author',
 path => 'OPL_path',
 pgfile => 'OPL_pgfile',
 keyword => 'OPL_keyword',
 pgfile_keyword => 'OPL_pgfile_keyword',
 textbook => 'OPL_textbook',
 chapter => 'OPL_chapter',
 section => 'OPL_section',
 problem => 'OPL_problem',
 morelt => 'OPL_morelt',
 pgfile_problem => 'OPL_pgfile_problem',
);

my %BPLtables = (
 dbsubject => 'BPL_DBsubject',
 dbchapter => 'BPL_DBchapter',
 dbsection => 'BPL_DBsection',
 author => 'BPL_author',
 path => 'BPL_path',
 pgfile => 'BPL_pgfile',
 keyword => 'BPL_keyword',
 keywordmap => 'BPL_keyword_chapters',
 keyworddim => 'BPL_keyword_dim',
 keywordrank => 'BPL_keyword_rank',
 pgfile_keyword => 'BPL_pgfile_keyword',
 textbook => 'BPL_textbook',
 chapter => 'BPL_chapter',
 section => 'BPL_section',
 problem => 'BPL_problem',
 morelt => 'BPL_morelt',
 pgfile_problem => 'BPL_pgfile_problem',
);

my %BPLENtables = (
 dbsubject => 'BPLen_DBsubject',
 dbchapter => 'BPLen_DBchapter',
 dbsection => 'BPLen_DBsection',
 author => 'BPLen_author',
 path => 'BPLen_path',
 pgfile => 'BPLen_pgfile',
 keyword => 'BPLen_keyword',
 keywordmap => 'BPLen_keyword_chapters',
 keyworddim => 'BPLen_keyword_dim',
 keywordrank => 'BPLen_keyword_rank',
 pgfile_keyword => 'BPLen_pgfile_keyword',
 textbook => 'BPLen_textbook',
 chapter => 'BPLen_chapter',
 section => 'BPLen_section',
 problem => 'BPLen_problem',
 morelt => 'BPLen_morelt',
 pgfile_problem => 'BPLen_pgfile_problem',
);

my %NPLtables = (
 dbsubject => 'NPL-DBsubject',
 dbchapter => 'NPL-DBchapter',
 dbsection => 'NPL-DBsection',
 author => 'NPL-author',
 path => 'NPL-path',
 pgfile => 'NPL-pgfile',
 keyword => 'NPL-keyword',
 pgfile_keyword => 'NPL-pgfile-keyword',
 textbook => 'NPL-textbook',
 chapter => 'NPL-chapter',
 section => 'NPL-section',
 problem => 'NPL-problem',
 morelt => 'NPL-morelt',
 pgfile_problem => 'NPL-pgfile-problem',
);


sub getTables {
	my $ce = shift;
        my $typ = shift;
	my $libraryRoot = $ce->{problemLibrary}->{root};
	my %tables;




       if($ce->{problemLibrary}->{version} == 2.5 && $typ ne 'BPL' && $typ ne 'BPLEN') {
                %tables = %OPLtables;
       } elsif($typ eq 'BPL') {
		%tables = %BPLtables;
       } elsif($typ eq 'BPLEN') {
		%tables = %BPLENtables;
       } else {
		%tables = %NPLtables;
       }
       return %tables;
}

sub getDB {
	my $ce = shift;
	my $dbh = DBI->connect(
		$ce->{problemLibrary_db}->{dbsource},
		$ce->{problemLibrary_db}->{user},
		$ce->{problemLibrary_db}->{passwd},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	die "Cannot connect to problem library database" unless $dbh;
	return($dbh);
}

=over

=item getProblemTags($path) and setProblemTags($path, $subj, $chap, $sect)
Get and set tags using full path and Tagging module
                                                                                
=cut

sub getProblemTags {
	my $path = shift;
	my $tags = WeBWorK::Utils::Tags->new($path);
	my %thash = ();
	for my $j ('DBchapter', 'DBsection', 'DBsubject', 'Level', 'Status') {
		$thash{$j} = $tags->{$j};
	}
	return \%thash;
}

sub setProblemTags {
	my $path = shift;
        if (-w $path) {
		my $subj= shift;
		my $chap = shift;
		my $sect = shift;
		my $level = shift;
		my $status = shift || 0;
		my $tags = WeBWorK::Utils::Tags->new($path);
		$tags->settag('DBsubject', $subj, 1);
		$tags->settag('DBchapter', $chap, 1);
		$tags->settag('DBsection', $sect, 1);
		$tags->settag('Level', $level, 1);
		$tags->settag('Status', $status, 1);
		eval {
			$tags->write();
			1;
		} or do {
			return [0, "Problem writing file"];
		};
		return [1, "Tags written"];
        } else {
		return [0, "Do not have permission to write to the problem file"];
	}
}

=item kwtidy($s) and keywordcleaner($s)
Both take a string and perform utility functions related to keywords.
keywordcleaner splits a string, and uses kwtidy to regularize punctuation
and case for an individual entry.
                                                                                
=cut                                                                            

sub kwtidy {
	my $s = shift;
	$s =~ s/\W//g;
	$s =~ s/_//g;
	$s = lc($s);
	return($s);
}

sub keywordCleaner {
	my $string = shift;
	my @spl1 = split /\s*,\s*/, $string;
	my @spl2 = map(kwtidy($_), @spl1);
	return(@spl2);
}

sub makeKeywordWhere {
	my $kwstring = shift;
	my @kwlist = keywordCleaner($kwstring);
#	@kwlist = map { "kw.keyword = \"$_\"" } @kwlist;
	my @kwlistqm = map { "kw.keyword = ? " } @kwlist;
	my $where = join(" OR ", @kwlistqm);
	return "AND ( $where )", @kwlist;
}
sub makeKeywordWhereAND {
	my $kwstring = shift;
	my @kwlist = keywordCleaner($kwstring);
#	@kwlist = map { "kw.keyword = \"$_\"" } @kwlist;
	my @kwlistqm = map { "kw.keyword = ? " } @kwlist;
	my $where = join(" AND ", @kwlistqm);
	return "AND ( $where )", @kwlist;
}
=item getDBextras($path)
Get flags for whether a pg file uses Math Objects, and if it is static

$r is a Apache request object so we can get the right table names

$path is the path to the file

Out put is an array reference: [MO, static]

=cut

sub getDBextras {
	my $r = shift;
	my $path = shift;
	my %tables = getTables($r->ce);
	my $dbh = getDB($r->ce);
	my ($mo, $static)=(0,0);

	$path =~ s|^Library/||;
	my $filename = basename $path;
	$path = dirname $path;
	my $query = "SELECT pgfile.MO, pgfile.static FROM `$tables{pgfile}` pgfile, `$tables{path}` p WHERE p.path=\"$path\" AND pgfile.path_id=p.path_id AND pgfile.filename=\"$filename\"";
	my @res = $dbh->selectrow_array($query);
	if(@res) {
		$mo = $res[0];
		$static = $res[1];
	}

	return [$mo, $static];
}

=item getDBTextbooks($r)                                                    
Returns textbook dependent entries.
                                                                                
$r is a Apache request object so we can extract whatever parameters we want

$thing is a string of either 'textbook', 'textchapter', or 'textsection' to
specify what to return.

If we are to return textbooks, then return an array of textbook names
consistent with the DB subject, chapter, section selected.

=cut

sub getDBTextbooks {
	my $r = shift;
	my $thing = shift || 'textbook';
	my $dbh = getDB($r->ce);
	my %tables = getTables($r->ce);
	my $extrawhere = '';
	# Handle DB* restrictions
	my @search_params=();
	my $subj = $r->param('library_subjects') || "";
        $subj = "" if($subj eq $r->maketext("All Subjects"));
	my $chap = $r->param('library_chapters') || "";
        $chap = "" if($chap eq $r->maketext("All Chapters"));
	my $sec = $r->param('library_sections') || "";
        $sec = "" if($sec eq $r->maketext("All Sections"));

	if($subj) {
		$subj =~ s/'/\\'/g;
		$extrawhere .= " AND t.name = ?\n";
		push @search_params, $subj;
	}
	if($chap) {
		$chap =~ s/'/\\'/g;
		$extrawhere .= " AND c.name = ? AND c.DBsubject_id=t.DBsubject_id\n";
		push @search_params, $chap;
	}
	if($sec) {
		$sec =~ s/'/\\'/g;
		$extrawhere .= " AND s.name = ? AND s.DBchapter_id = c.DBchapter_id AND s.DBsection_id=pgf.DBsection_id";
		push @search_params, $sec;
	}
	my $textextrawhere = '';
	my $textid = $r->param('library_textbook') || '';
        $textid = "" if($textid eq $r->maketext("All Textbooks"));
	if($textid and $thing ne 'textbook') {
		$textextrawhere .= " AND tbk.textbook_id= ? ";
		push @search_params, $textid;
	} else {
		return([]) if($thing ne 'textbook');
	}

	my $textchap = $r->param('library_textchapter') || '';
        $textchap = "" if($textchap eq $r->maketext("All Chapters"));

	$textchap =~ s/^\s*\d+\.\s*//;
	if($textchap and $thing eq 'textsection') {
		$textextrawhere .= " AND tc.name= ? ";
		push @search_params, $textchap;
	} else {
		return([]) if($thing eq 'textsection');
	}

	my $selectwhat = LIBRARY_STRUCTURE->{$thing}{select};
	
# 	my $query = "SELECT DISTINCT $selectwhat
#           FROM `$tables{textbook}` tbk, `$tables{problem}` prob, 
# 			`$tables{pgfile_problem}` pg, `$tables{pgfile}` pgf,
#             `$tables{dbsection}` s, `$tables{dbchapter}` c, `$tables{dbsubject}` t,
# 			`$tables{chapter}` tc, `$tables{section}` ts
#           WHERE ts.section_id=prob.section_id AND 
#             prob.problem_id=pg.problem_id AND
#             s.DBchapter_id=c.DBchapter_id AND 
#             c.DBsubject_id=t.DBsubject_id AND
#             pgf.DBsection_id=s.DBsection_id AND
#             pgf.pgfile_id=pg.pgfile_id AND
#             ts.chapter_id=tc.chapter_id AND
#             tc.textbook_id=tbk.textbook_id
#             $extrawhere $textextrawhere ";
	my $query = "SELECT DISTINCT $selectwhat
          FROM `$tables{textbook}` tbk, `$tables{problem}` prob, 
			`$tables{pgfile_problem}` pg, `$tables{pgfile}` pgf,
            `$tables{dbsection}` s, `$tables{dbchapter}` c, `$tables{dbsubject}` t,
			`$tables{chapter}` tc, `$tables{section}` ts
          WHERE ts.section_id=prob.section_id AND 
            prob.problem_id=pg.problem_id AND
            s.DBchapter_id=c.DBchapter_id AND 
            c.DBsubject_id=t.DBsubject_id AND
            pgf.DBsection_id=s.DBsection_id AND
            pgf.pgfile_id=pg.pgfile_id AND
            ts.chapter_id=tc.chapter_id AND
            tc.textbook_id=tbk.textbook_id
            $extrawhere $textextrawhere  ";

#$query =~ s/\n/ /g;
#warn "query:", $query;
#warn "params:", join(" | ", @search_params);
#	my $text_ref = $dbh->selectall_arrayref($query);
    my $text_ref = $dbh->selectall_arrayref($query,{},@search_params);  #FIXME

	my @texts = @{$text_ref};
	if( $thing eq 'textbook') {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[1] . $_->[2] . $_->[3] } @texts;
		@texts = indirectSortByName( \@sortarray, @texts );
		return(\@texts);
	} else {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[0] .". " . $_->[1] } @texts;
		@texts = map { [ $_ ] } @sortarray;
		@texts = indirectSortByName(\@sortarray, @texts);
		return(\@texts);
	}
}

=item getAllDBsubjects($r)
Returns an array of DBsubject names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBsubjects {
	my $r = shift;
        my $typ = shift || 'OPL';
        if($r->param('library_srchtype') eq 'BPL') { $typ = 'BPL'; }
        if($r->param('library_srchtype') eq 'BPLEN') { $typ = 'BPLEN'; }
	my %tables = getTables($r->ce, $typ);
	my @results=();
	my @row;
	my $query = "SELECT DISTINCT name, DBsubject_id FROM `$tables{dbsubject}` ORDER BY name";
	my $dbh = getDB($r->ce);
	my $sth = $dbh->prepare($query);
	$sth->execute();

	while (@row = $sth->fetchrow_array()) {
		push @results, Encode::decode_utf8($row[0]);
	}
	# @results = sortByName(undef, @results);
	return @results;
}

=item getAllKeyWords($r)
Returns an array of keywords starting

$r is the Apache request object

=cut
sub getAllKeyWords_en {
	my $r = shift;
        my $typ = 'BPLEN';
	my %tables = getTables($r->ce, 'BPLEN');
	my @results=();
	my $subject = $r->param('library_subjects');
	my $chapter = $r->param('library_chapters');
        $subject = "" if($subject eq $r->maketext("All Subjects"));
        $chapter = "" if($chapter eq $r->maketext("All Chapters"));

	my $keywords =  $r->param('library_keywords') || "";
        my $limit = $r->param('library_defkeywordsen') || 10000;
        my $row;
        my $kwwhere;
        my $exwhere;
        my $AllKeyWords = {};
        my $PgKeyWords = {};

	my $dbh = getDB($r->ce);

        my $query = "SELECT s.*,r.kwrank FROM  `$tables{keyworddim}` s , `$tables{keywordrank}` r WHERE r.keyword_id = s.keyword_id";

        my $hash = $dbh->selectall_arrayref($query);
        foreach my $rw (@$hash) {
              my ($keyword_id,$keyword,$chapter_id,$chapter,$subject_id,$subject,$pgfile_id,$rank) = @$rw;
              push @{$PgKeyWords->{$keyword}->{pgfile_id}}, $pgfile_id;
        }

        my %ExclPGFILE;
        my %InclPGFILE;
        my %SrchKeyWords;

        if($keywords ne "") {
            my $firstLoop = 1;
            my %lastSet;
            my @tags = split ',',$keywords;
 
            foreach my $kw (@tags) {
                my $pgfiles;
                $kw =~s/^\s+//g;
                $kw =~s/\s+$//g;
                $SrchKeyWords{$kw} = 1;
                if($kw =~/^-/) {
                    $kw =~s/^-//;
                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                     
                    foreach (  @$pgfiles ) {
                       $ExclPGFILE{$_} = 1;
                    }
                } else {

                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                    %lastSet = map{ $_ =>1 } @$pgfiles if($firstLoop);
                    my @masterSet = grep( $lastSet{$_}, @$pgfiles );
                    %lastSet = map{$_ =>1} @masterSet;
                    $firstLoop = 0 if($firstLoop);

                }
                %InclPGFILE=%lastSet;
            }
        }

	foreach my $w (@$hash) {

              my ($keyword_id,$keyword,$chapter_id,$DBchapter,$subject_id,$DBsubject,$pgfile_id,$rank) = @$w;

              next if(exists($SrchKeyWords{$keyword}));
              next if($subject ne "" && $DBsubject ne $subject);
              next if($chapter ne "" && $DBchapter ne $chapter);
              next if(scalar(keys %ExclPGFILE) > 0 && exists $ExclPGFILE{$pgfile_id});

              next if(scalar(keys %InclPGFILE) > 0 && not exists $InclPGFILE{$pgfile_id});

              $AllKeyWords->{$keyword}->{kwrank}    = $rank || 0;

        }
=comment
        my @results = sort { $AllKeyWords->{$b}{kwrank} <=> $AllKeyWords->{$a}{kwrank} } keys %$AllKeyWords;
        $limit = (scalar(@results) > $limit) ? $limit : scalar(@results);
#       $dbh->do("CREATE TEMPORARY TABLE topkeywords (keyword varchar(100)) DEFAULT CHARSET=latin1");
	$dbh->do("CREATE TEMPORARY TABLE topkeywords (keyword varchar(100))");      
	s/'/\\'/g for @results;
        my $kwinsert =  join "'),('", @results[0..$limit-1];
        $kwinsert = "('".$kwinsert."')";
        $dbh->do("INSERT INTO topkeywords (keyword) values $kwinsert");
        my $keywords = $dbh->selectcol_arrayref("SELECT keyword from topkeywords ORDER BY CONVERT(CAST(keyword as BINARY) USING utf8)");
        $dbh->do("DROP TABLE topkeywords");
=cut
 
        my @kws;
        foreach (keys %$AllKeyWords) {
            push @kws, $_;
            push @kws, "-".$_;
        }


        return @kws;
}
sub getAllKeyWords {
	my $r = shift;
        my $typ = 'BPL';
        if($r->param('library_srchtype') eq 'BPLEN') { $typ = 'BPLEN'; }
	my %tables = getTables($r->ce, $typ);
	#my %tables = getTables($r->ce, 'BPL');
	my @results=();
	my $subject = $r->param('library_subjects');
	my $chapter = $r->param('library_chapters');
        $subject = "" if($subject eq $r->maketext("All Subjects"));
        $chapter = "" if($chapter eq $r->maketext("All Chapters"));
        
        # for comparison in the db with utf8 characters
	$subject = Encode::encode_utf8($subject);
	$chapter = Encode::encode_utf8($chapter);

	my $keywords =  $r->param('library_keywords') || "";
        my $limit = $r->param('library_defkeywords') || 10000;
        my $row;
        my $kwwhere;
        my $exwhere;
        my $AllKeyWords = {};
        my $PgKeyWords = {};

	my $dbh = getDB($r->ce);
	
        my $query = "SELECT s.*,r.kwrank FROM  `$tables{keyworddim}` s , `$tables{keywordrank}` r WHERE r.keyword_id = s.keyword_id";
#print STDERR "\n\n\n\n\n$query\n\n\n\n";

        my $hash = $dbh->selectall_arrayref($query);
        foreach my $rw (@$hash) {
              my ($keyword_id,$keyword,$chapter_id,$chapter,$subject_id,$subject,$pgfile_id,$rank) = @$rw;
              push @{$PgKeyWords->{$keyword}->{pgfile_id}}, $pgfile_id;
        }

        my %ExclPGFILE;
        my %InclPGFILE;
        my %SrchKeyWords;

        if($keywords ne "") {
            my $firstLoop = 1;
            my %lastSet;
            my @tags = split ',',$keywords;
 
            foreach my $kw (@tags) {
                my $pgfiles;
                $kw =~s/^\s+//g;
                $kw =~s/\s+$//g;
                $SrchKeyWords{$kw} = 1;
                if($kw =~/^-/) {
                    $kw =~s/^-//;
                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                     
                    foreach (  @$pgfiles ) {
                       $ExclPGFILE{$_} = 1;
                    }
                } else {

                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                    %lastSet = map{ $_ =>1 } @$pgfiles if($firstLoop);
                    my @masterSet = grep( $lastSet{$_}, @$pgfiles );
                    %lastSet = map{$_ =>1} @masterSet;
                    $firstLoop = 0 if($firstLoop);

                }
                %InclPGFILE=%lastSet;
            }
        }

	foreach my $w (@$hash) {

              my ($keyword_id,$keyword,$chapter_id,$DBchapter,$subject_id,$DBsubject,$pgfile_id,$rank) = @$w;

              next if(exists($SrchKeyWords{$keyword}));
              next if($subject ne "" && $DBsubject ne $subject);
              next if($chapter ne "" && $DBchapter ne $chapter);
              next if(scalar(keys %ExclPGFILE) > 0 && exists $ExclPGFILE{$pgfile_id});

              next if(scalar(keys %InclPGFILE) > 0 && not exists $InclPGFILE{$pgfile_id});

              $AllKeyWords->{$keyword}->{kwrank}    = $rank || 0;

        }
=comment
        my @results = sort { $AllKeyWords->{$b}{kwrank} <=> $AllKeyWords->{$a}{kwrank} } keys %$AllKeyWords;
        $limit = (scalar(@results) > $limit) ? $limit : scalar(@results);
        $dbh->do("CREATE TEMPORARY TABLE topkeywords (keyword varchar(100)) DEFAULT CHARSET=latin1");
        s/'/\\'/g for @results;
        my $kwinsert =  join "'),('", @results[0..$limit-1];
        $kwinsert = "('".$kwinsert."')";
        $dbh->do("INSERT INTO topkeywords (keyword) values $kwinsert");
        my $keywords = $dbh->selectcol_arrayref("SELECT keyword from topkeywords ORDER BY CONVERT(CAST(keyword as BINARY) USING utf8)");
        $dbh->do("DROP TABLE topkeywords");
=cut
 
        my @kws;
        foreach (keys %$AllKeyWords) {
            $_ = Encode::decode_utf8( $_ );
            push @kws, $_;
            push @kws, "-".$_;
        }
	
        return @kws;
}

=item getAllKeyWords($r)
Returns an array of keywords starting

$r is the Apache request object

=cut
sub getTop20KeyWords_en {
	my $r = shift;
        my $typ = 'BPLEN';
	my %tables = getTables($r->ce, 'BPLEN');
	my @results=();
	my $subject = $r->param('library_subjects');
	my $chapter = $r->param('library_chapters');
        $subject = "" if($subject eq $r->maketext("All Subjects"));
        $chapter = "" if($chapter eq $r->maketext("All Chapters"));

	my $keywords =  $r->param('library_keywords') || "";
        my $limit = $r->param('library_defkeywords') || 20;
        my $row;
        my $kwwhere;
        my $exwhere;
        my $AllKeyWords = {};
        my $PgKeyWords = {};

	my $dbh = getDB($r->ce);

        my $query = "SELECT s.*,r.kwrank FROM  `$tables{keyworddim}` s , `$tables{keywordrank}` r WHERE r.keyword_id = s.keyword_id";

        my $hash = $dbh->selectall_arrayref($query);
        foreach my $rw (@$hash) {
              my ($keyword_id,$keyword,$chapter_id,$chapter,$subject_id,$subject,$pgfile_id,$rank) = @$rw;
              push @{$PgKeyWords->{$keyword}->{pgfile_id}}, $pgfile_id;
        }

        my %ExclPGFILE;
        my %InclPGFILE;
        my %SrchKeyWords;

        if($keywords ne "") {
            my $firstLoop = 1;
            my %lastSet;
            my @tags = split ',',$keywords;
 
            foreach my $kw (@tags) {
                my $pgfiles;
                $kw =~s/^\s+//g;
                $kw =~s/\s+$//g;
                $SrchKeyWords{$kw} = 1;
                if($kw =~/^-/) {
                    $kw =~s/^-//;
                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                     
                    foreach (  @$pgfiles ) {
                       $ExclPGFILE{$_} = 1;
                    }
                } else {

                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                    %lastSet = map{ $_ =>1 } @$pgfiles if($firstLoop);
                    my @masterSet = grep( $lastSet{$_}, @$pgfiles );
                    %lastSet = map{$_ =>1} @masterSet;
                    $firstLoop = 0 if($firstLoop);

                }
                %InclPGFILE=%lastSet;
            }
        }

	foreach my $w (@$hash) {

              my ($keyword_id,$keyword,$chapter_id,$DBchapter,$subject_id,$DBsubject,$pgfile_id,$rank) = @$w;

              next if(exists($SrchKeyWords{$keyword}));
              next if($subject ne "" && $DBsubject ne $subject);
              next if($chapter ne "" && $DBchapter ne $chapter);
              next if(scalar(keys %ExclPGFILE) > 0 && exists $ExclPGFILE{$pgfile_id});

              next if(scalar(keys %InclPGFILE) > 0 && not exists $InclPGFILE{$pgfile_id});

              $AllKeyWords->{$keyword}->{kwrank}    = $rank || 0;

        }
        my @results = sort { $AllKeyWords->{$b}{kwrank} <=> $AllKeyWords->{$a}{kwrank} } keys %$AllKeyWords;
        $limit = (scalar(@results) > $limit) ? $limit : scalar(@results);
	$dbh->do("CREATE TEMPORARY TABLE topkeywords (keyword varchar(100))");
        s/'/\\'/g for @results;
        my $kwinsert =  join "'),('", @results[0..$limit-1];
        $kwinsert = "('".$kwinsert."')";
        $dbh->do("INSERT INTO topkeywords (keyword) values $kwinsert");
        my $keywords = $dbh->selectcol_arrayref("SELECT keyword from topkeywords ORDER BY keyword");

        return @$keywords;
}
sub getTop20KeyWords {
	my $r = shift;
        my $typ = 'BPL';
        if($r->param('library_srchtype') eq 'BPLEN') { $typ = 'BPLEN'; }
	my %tables = getTables($r->ce, $typ);
	my @results=();
	my $subject = $r->param('library_subjects');
	my $chapter = $r->param('library_chapters');
        $subject = "" if($subject eq $r->maketext("All Subjects"));
        $chapter = "" if($chapter eq $r->maketext("All Chapters"));
        
	# for comparison in the db with utf8 characters
	$subject = Encode::encode_utf8($subject);
	$chapter = Encode::encode_utf8($chapter);

	my $keywords =  $r->param('library_keywords') || "";
        my $limit = $r->param('library_defkeywords') || 20;
        my $row;
        my $kwwhere;
        my $exwhere;
        my $AllKeyWords = {};
        my $PgKeyWords = {};

	my $dbh = getDB($r->ce);
		
        my $query = "SELECT s.*,r.kwrank FROM  `$tables{keyworddim}` s , `$tables{keywordrank}` r WHERE r.keyword_id = s.keyword_id";

        my $hash = $dbh->selectall_arrayref($query);
        foreach my $rw (@$hash) {
              my ($keyword_id,$keyword,$chapter_id,$chapter,$subject_id,$subject,$pgfile_id,$rank) = @$rw;
              push @{$PgKeyWords->{$keyword}->{pgfile_id}}, $pgfile_id;
        }

        my %ExclPGFILE;
        my %InclPGFILE;
        my %SrchKeyWords;

        if($keywords ne "") {
            my $firstLoop = 1;
            my %lastSet;
            my @tags = split ',',$keywords;
 
            foreach my $kw (@tags) {
                my $pgfiles;
                $kw =~s/^\s+//g;
                $kw =~s/\s+$//g;
                $SrchKeyWords{$kw} = 1;
                if($kw =~/^-/) {
                    $kw =~s/^-//;
                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                     
                    foreach (  @$pgfiles ) {
                       $ExclPGFILE{$_} = 1;
                    }
                } else {

                    $pgfiles = $PgKeyWords->{$kw}->{pgfile_id};
                    %lastSet = map{ $_ =>1 } @$pgfiles if($firstLoop);
                    my @masterSet = grep( $lastSet{$_}, @$pgfiles );
                    %lastSet = map{$_ =>1} @masterSet;
                    $firstLoop = 0 if($firstLoop);

                }
                %InclPGFILE=%lastSet;
            }
        }

	foreach my $w (@$hash) {

              my ($keyword_id,$keyword,$chapter_id,$DBchapter,$subject_id,$DBsubject,$pgfile_id,$rank) = @$w;

              next if(exists($SrchKeyWords{$keyword}));
              next if($subject ne "" && $DBsubject ne $subject);
              next if($chapter ne "" && $DBchapter ne $chapter);
              next if(scalar(keys %ExclPGFILE) > 0 && exists $ExclPGFILE{$pgfile_id});

              next if(scalar(keys %InclPGFILE) > 0 && not exists $InclPGFILE{$pgfile_id});

              $AllKeyWords->{$keyword}->{kwrank}    = $rank || 0;

        }
        my @results = sort { $AllKeyWords->{$b}{kwrank} <=> $AllKeyWords->{$a}{kwrank} } keys %$AllKeyWords;
        $limit = (scalar(@results) > $limit) ? $limit : scalar(@results);
        $dbh->do("CREATE TEMPORARY TABLE topkeywords (keyword varchar(100))");
        s/'/\\'/g for @results;
        my $kwinsert =  join "'),('", @results[0..$limit-1];
        $kwinsert = "('".$kwinsert."')";
        $dbh->do("INSERT INTO topkeywords (keyword) values $kwinsert");
        my $keywords = $dbh->selectcol_arrayref("SELECT keyword from topkeywords ORDER BY keyword");
        
        my @kws;
        foreach (@$keywords) {
            push @kws, Encode::decode_utf8( $_ );
	}
	
        return @kws;
}


=item getAllDBchapters($r)
Returns an array of DBchapter names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBchapters {
	my $r = shift;
        my $typ = shift || 'OPL';

        if($r->param('library_srchtype') eq 'BPL') { 
           $typ = 'BPL'; 
        }
        if($r->param('library_srchtype') eq 'BPLEN') { 
           $typ = 'BPLEN'; 
        }
	my %tables = getTables($r->ce,$typ);
	my $subject = $r->param('library_subjects');
        $subject = $r->param('blibrary_subjects') if($typ eq 'BPL');
        $subject = $r->param('benlibrary_subjects') if($typ eq 'BPLEN');
        
        #utf8::upgrade($subject);
        $subject = Encode::encode_utf8($subject);
        
	return () unless($subject);
	my $dbh = getDB($r->ce);
# 	my $query = "SELECT DISTINCT c.name, c.DBchapter_id 
#                                 FROM `$tables{dbchapter}` c, 
# 				`$tables{dbsubject}` t
#                  WHERE c.DBsubject_id = t.DBsubject_id AND
#                  t.name = \"$subject\" ORDER BY c.DBchapter_id";
# 	my $all_chaps_ref = $dbh->selectall_arrayref($query);
	my $query = "SELECT DISTINCT c.name, c.DBchapter_id 
                                FROM `$tables{dbchapter}` c, 
				`$tables{dbsubject}` t
                 WHERE c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? ORDER BY c.name";
       
	my $all_chaps_ref = $dbh->selectall_arrayref($query, {},$subject);
 	my @results = map { Encode::decode_utf8($_->[0]) } @{$all_chaps_ref};
	#@results = sortByName(undef, @results);
	return @results;
}

=item getAllDBsections($r)                                            
Returns an array of DBsection names                                             
                                                                                
$r is the Apache request object

=cut                                                                            

sub getAllDBsections {
	my $r = shift;
        my $typ = 'OPL';
	my %tables = getTables($r->ce, $typ);
	my $subject = $r->param('library_subjects');
	return () unless($subject);
	my $chapter = $r->param('library_chapters');
	return () unless($chapter);
	my $dbh = getDB($r->ce);
# 	my $query = "SELECT DISTINCT s.name, s.DBsection_id 
#                  FROM `$tables{dbsection}` s,
#                  `$tables{dbchapter}` c, `$tables{dbsubject}` t
#                  WHERE s.DBchapter_id = c.DBchapter_id AND
#                  c.DBsubject_id = t.DBsubject_id AND
#                  t.name = \"$subject\" AND c.name = \"$chapter\" ORDER BY s.DBsection_id";
# 	my $all_sections_ref = $dbh->selectall_arrayref($query);
	my $query = "SELECT DISTINCT s.name, s.DBsection_id 
                 FROM `$tables{dbsection}` s,
                 `$tables{dbchapter}` c, `$tables{dbsubject}` t
                 WHERE s.DBchapter_id = c.DBchapter_id AND
                 c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? AND c.name = ? ORDER BY s.DBsection_id";
	my $all_sections_ref = $dbh->selectall_arrayref($query, {},$subject, $chapter);

	my @results = map { $_->[0] } @{$all_sections_ref};
	#@results = sortByName(undef, @results);
	return @results;
}

=item getDBListings($r)                             
Returns an array of hash references with the keys: path, filename.              
                                                                                
$r is an Apache request object that has all needed data inside of it

Here, we search on all known fields out of r
                                                                                
=cut

sub getDBListings {
	my $r = shift;
	my $amcounter = shift;  # 0-1 if I am a counter.
	my $ce = $r->ce;
	my %tables = getTables($ce);
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";
	
	# Make sure these strings are internally encoded in UTF-8
	utf8::upgrade($subj);
	utf8::upgrade($chap);
	utf8::upgrade($sec);

	$subj = "" if ($subj eq $r->maketext("All Subjects"));
	$chap = "" if ($chap eq $r->maketext("All Chapters"));
	$sec = "" if ($sec eq $r->maketext("All Sections"));

	my $keywords = $r->param('library_keywords') || "";
	# Next could be an array, an array reference, or nothing
	my @levels = $r->param('level');
	if(scalar(@levels) == 1 and ref($levels[0]) eq 'ARRAY') {
		@levels = @{$levels[0]};
	}
	@levels = grep { defined($_) && m/\S/ } @levels;
	my ($kw1, $kw2) = ('','');
	my $keywordstring;
	my @keyword_params;
	if($keywords) {
		($keywordstring, @keyword_params) = makeKeywordWhere($keywords) ;
		$kw1 = ", `$tables{keyword}` kw, `$tables{pgfile_keyword}` pgkey";
		$kw2 = " AND kw.keyword_id=pgkey.keyword_id AND
			 pgkey.pgfile_id=pgf.pgfile_id $keywordstring"; 
#			makeKeywordWhere($keywords) ;
	}

	my $dbh = getDB($ce);

	my $extrawhere = '';
	my @select_parameters=();
	if($subj) {
#		$subj =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsj.name=\"$subj\" ";
		$extrawhere .= " AND dbsj.name= ? ";
		push @select_parameters, $subj;
	}
	if($chap) {
#		$chap =~ s/'/\\'/g;
#		$extrawhere .= " AND dbc.name=\"$chap\" ";
		$extrawhere .= " AND dbc.name= ? ";
		push @select_parameters, $chap;
	}
	if($sec) {
#		$sec =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsc.name=\"$sec\" ";
		$extrawhere .= " AND dbsc.name= ? ";
		push @select_parameters, $sec;
	}
	if(scalar(@levels)) {
#		$extrawhere .= " AND pgf.level IN (".join(',', @levels).") ";
		$extrawhere .= " AND pgf.level IN ( ? ) ";
		push @select_parameters, join(',', @levels);
	}
	my $textextrawhere = '';
    my $haveTextInfo=0;
    my @textInfo_parameters=();
	for my $j (qw( textbook textchapter textsection )) {
		my $foo = $r->param(LIBRARY_STRUCTURE->{$j}{name}) || '';
		$foo = "" if($foo eq $r->maketext( LIBRARY_STRUCTURE->{$j}{all} ));
		$foo =~ s/^\s*\d+\.\s*//;
		if($foo) {
            $haveTextInfo=1;
			$foo =~ s/'/\\'/g;
			$textextrawhere .= " AND ".LIBRARY_STRUCTURE->{$j}{where}."= ? ";
			push @textInfo_parameters, $foo;
		}
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = 'COUNT(' . $selectwhat . ')' if ($amcounter);

# 	my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
#          `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
#         WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
#               dbc.DBchapter_id = dbsc.DBchapter_id AND
#               dbsc.DBsection_id = pgf.DBsection_id 
#               \n $extrawhere 
#               $kw2";

	my $pg_id_ref;
	
	$dbh->do(qq{SET NAMES 'utf8mb4';}) if $ce->{ENABLE_UTF8MB4};
	if($haveTextInfo) {
		my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
			`$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj,
			`$tables{pgfile_problem}` pgp, `$tables{problem}` prob, `$tables{textbook}` tbk ,
			`$tables{chapter}` tc, `$tables{section}` ts $kw1
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				  dbc.DBchapter_id = dbsc.DBchapter_id AND
				  dbsc.DBsection_id = pgf.DBsection_id AND
				  pgf.pgfile_id = pgp.pgfile_id AND
				  pgp.problem_id = prob.problem_id AND
				  tc.textbook_id = tbk.textbook_id AND
				  ts.chapter_id = tc.chapter_id AND
				  prob.section_id = ts.section_id \n $extrawhere \n $textextrawhere
				  $kw2";
				  
		#$query =~ s/\n/ /g;
		#warn "text info: ", $query;
		#warn "params: ", join(" | ",@select_parameters, @textInfo_parameters,@keyword_params);
		
		$pg_id_ref = $dbh->selectall_arrayref($query, {},@select_parameters, @textInfo_parameters, @keyword_params);

     } else {
		my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
			 `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				  dbc.DBchapter_id = dbsc.DBchapter_id AND
				  dbsc.DBsection_id = pgf.DBsection_id 
				  \n $extrawhere 
				  $kw2";
				  
		#$query =~ s/\n/ /g;
		#warn "no text info: ", $query;
		#warn "params: ", join(" | ",@select_parameters,@keyword_params);

     	$pg_id_ref = $dbh->selectall_arrayref($query,{},@select_parameters,@keyword_params);
     	#$query =~ s/\n/ /g;

     }

	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	if($amcounter) {
		return(@pg_ids[0]);
	}
	my @results=();
	for my $pgid (@pg_ids) {
# 		$query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
#           WHERE p.path_id = pgf.path_id AND pgf.pgfile_id=\"$pgid\"";
# 		my $row = $dbh->selectrow_arrayref($query);
		my $query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id= ? ";
		my $row = $dbh->selectrow_arrayref($query,{},$pgid);

		push @results, {'path' => $row->[0], 'filename' => $row->[1], 'morelt' => $row->[2], 'pgid'=> $row->[3], 'static' => $row->[4], 'MO' => $row->[5] };
		
	}
	return @results;
}
sub getBPLENDBListings {
	my $r = shift;
	my $amcounter = shift;  # 0-1 if I am a counter.
        my $typ = "BPLEN";

	my $ce = $r->ce;
	my %tables = getTables($ce,'BPLEN');

	my $subj = $r->param('benlibrary_subjects') || "";
	my $chap = $r->param('benlibrary_chapters') || "";

        $subj = "" if ($subj eq $r->maketext("All Subjects"));
        $chap = "" if ($chap eq $r->maketext("All Chapters")); 
	my $sec = "";

	# Make sure these strings are internally encoded in UTF-8
	#utf8::upgrade($subj);
	#utf8::upgrade($chap);
	#utf8::upgrade($sec);	
	$subj = Encode::encode_utf8($subj);
	$chap = Encode::encode_utf8($chap);
	
	
	my $keywords =  $r->param('library_keywords') || $r->param('search_bplen') || "";
	my $dbh = getDB($ce);

	# Next could be an array, an array reference, or nothing
	my @levels = $r->param('level');
	if(scalar(@levels) == 1 and ref($levels[0]) eq 'ARRAY') {
		@levels = @{$levels[0]};
	}
	@levels = grep { defined($_) && m/\S/ } @levels;
	my ($kw1, $kw2) = ('','');

        #Hack for BPL new interface
        if($keywords ne "") {
            my @tags = split(',',$keywords);
            my $k=0;

	    $kw1 = ", `$tables{keywordmap}` kc, `$tables{keyword}` kw, `$tables{pgfile_keyword}` pgkey";
	    $kw2 = " AND kw.keyword_id=pgkey.keyword_id 
                     AND kc.bpldbchapter_id = dbc.DBchapter_id 
                     AND kw.keyword_id=kc.bplkeyword_id 
                     AND pgkey.pgfile_id=pgf.pgfile_id";

            if(scalar(@tags) > 0) {
              foreach my $t (@tags) {
               $t=~s/\s+$//g;
                $t=~s/^\s+//g;
                $k++;
                # Make sure these strings are internally encoded in UTF-8
		 #utf8::upgrade($t);
                $t = Encode::encode_utf8($t);
                if($t=~/^-/) {
                    $t =~s/^-//;
                    $kw2 .= " AND NOT EXISTS (select 1 from  `$tables{keyword}` kw$k,`$tables{pgfile_keyword}` pgkey$k where kw$k.keyword = \"$t\" and kw$k.keyword_id=pgkey$k.keyword_id AND pgkey$k.pgfile_id = pgkey.pgfile_id ) \n";
                } else {
                    $kw2 .= " AND EXISTS (select 1 from  `$tables{keyword}` kw$k,`$tables{pgfile_keyword}` pgkey$k where kw$k.keyword = \"$t\" and kw$k.keyword_id=pgkey$k.keyword_id AND pgkey$k.pgfile_id = pgkey.pgfile_id ) \n";
                }
                ###Rank them here 
                $t =~s/^-//;
              }
            }
        }

	my $extrawhere = '';
	my @select_parameters=();

	
	if($subj) {
#		$subj =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsj.name=\"$subj\" ";
		$extrawhere .= " AND dbsj.name= ? ";
		push @select_parameters, $subj;
	}
	if($chap) {
#		$chap =~ s/'/\\'/g;
#		$extrawhere .= " AND dbc.name=\"$chap\" ";
		$extrawhere .= " AND dbc.name= ? ";
		push @select_parameters, $chap;
	}
	if($sec) {
#		$sec =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsc.name=\"$sec\" ";
		$extrawhere .= " AND dbsc.name= ? ";
		push @select_parameters, $sec;
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = 'COUNT(' . $selectwhat . ')' if ($amcounter);
	
	my $query = "SELECT $selectwhat, pgf.filename from `$tables{pgfile}` pgf, 
         `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
        WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
              dbc.DBchapter_id = dbsc.DBchapter_id AND
              dbsc.DBsection_id = pgf.DBsection_id 
              \n $extrawhere 
              $kw2";
        $query .= " ORDER BY pgf.filename" if($typ eq 'BPLEN');


	my $pg_id_ref = $dbh->selectall_arrayref($query, {},@select_parameters);
	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	if($amcounter) {
	    return(@pg_ids[0]);
	}

	my @results=();
	for my $pgid (@pg_ids) {
#		$query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
#          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id=\"$pgid\"";
#		my $row = $dbh->selectrow_arrayref($query);
		my $query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id= ? ";
		my $row = $dbh->selectrow_arrayref($query,{},$pgid);
		
		push @results, {'path' => $row->[0], 'filename' => $row->[1], 'morelt' => $row->[2], 'pgid'=> $row->[3], 'static' => $row->[4], 'MO' => $row->[5] };
		
	}
        $dbh->disconnect;
	return @results;
}

sub getBPLDBListings {
	my $r = shift;
	my $amcounter = shift;  # 0-1 if I am a counter.
        my $typ = "BPL";

	my $ce = $r->ce;
	my %tables = getTables($ce,'BPL');

	my $subj = $r->param('blibrary_subjects') || "";
	my $chap = $r->param('blibrary_chapters') || "";

        $subj = "" if ($subj eq $r->maketext("All Subjects"));
        $chap = "" if ($chap eq $r->maketext("All Chapters"));
	my $sec = "";
	
	# Make sure these strings are internally encoded in UTF-8
	#utf8::upgrade($subj);
	#utf8::upgrade($chap);
	#utf8::upgrade($sec);
	$subj = Encode::encode_utf8($subj);
	$chap = Encode::encode_utf8($chap);
	
	my $keywords =  $r->param('library_keywords') || $r->param('search_bpl') || "";
	my $dbh = getDB($ce);      

	# Next could be an array, an array reference, or nothing
	my @levels = $r->param('level');
	if(scalar(@levels) == 1 and ref($levels[0]) eq 'ARRAY') {
		@levels = @{$levels[0]};
	}
	@levels = grep { defined($_) && m/\S/ } @levels;
	my ($kw1, $kw2) = ('','');

        #Hack for BPL new interface
        if($keywords ne "") {
            my @tags = split(',',$keywords);
            my $k=0;

	    $kw1 = ", `$tables{keywordmap}` kc, `$tables{keyword}` kw, `$tables{pgfile_keyword}` pgkey";
	    $kw2 = " AND kw.keyword_id=pgkey.keyword_id 
                     AND kc.bpldbchapter_id = dbc.DBchapter_id 
                     AND kw.keyword_id=kc.bplkeyword_id 
                     AND pgkey.pgfile_id=pgf.pgfile_id";

            if(scalar(@tags) > 0) {
              foreach my $t (@tags) {
                $t=~s/\s+$//g;
                $t=~s/^\s+//g;
                # Make sure these strings are internally encoded in UTF-8
		#utf8::upgrade($t);
               $t = Encode::encode_utf8($t);
                $k++;
                if($t=~/^-/) {
                    $t =~s/^-//;
                    $kw2 .= " AND NOT EXISTS (select 1 from  `$tables{keyword}` kw$k,`$tables{pgfile_keyword}` pgkey$k where kw$k.keyword = \"$t\" and kw$k.keyword_id=pgkey$k.keyword_id AND pgkey$k.pgfile_id = pgkey.pgfile_id ) \n";
                } else {
                    $kw2 .= " AND EXISTS (select 1 from  `$tables{keyword}` kw$k,`$tables{pgfile_keyword}` pgkey$k where kw$k.keyword = \"$t\" and kw$k.keyword_id=pgkey$k.keyword_id AND pgkey$k.pgfile_id = pgkey.pgfile_id ) \n";
                }
                ###Rank them here 
                $t =~s/^-//;
              }
            }
        }

	my $extrawhere = '';
	my @select_parameters=();
	
	if($subj) {
#		$subj =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsj.name=\"$subj\" ";
		$extrawhere .= " AND dbsj.name= ? ";
		push @select_parameters, $subj;
	}
	if($chap) {
#		$chap =~ s/'/\\'/g;
#		$extrawhere .= " AND dbc.name=\"$chap\" ";
		$extrawhere .= " AND dbc.name= ? ";
		push @select_parameters, $chap;
	}
	if($sec) {
#		$sec =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsc.name=\"$sec\" ";
		$extrawhere .= " AND dbsc.name= ? ";
		push @select_parameters, $sec;
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = 'COUNT(' . $selectwhat . ')' if ($amcounter);

	my $query = "SELECT $selectwhat, pgf.filename from `$tables{pgfile}` pgf, 
         `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
        WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
              dbc.DBchapter_id = dbsc.DBchapter_id AND
              dbsc.DBsection_id = pgf.DBsection_id 
              \n $extrawhere 
              $kw2";
        $query .= " ORDER BY pgf.filename" if($typ eq 'BPL');
#print STDERR "$query\n";


	my $pg_id_ref = $dbh->selectall_arrayref($query, {},@select_parameters);
	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	if($amcounter) {
	    return(@pg_ids[0]);
	}

	my @results=();
	for my $pgid (@pg_ids) {
#		$query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
#          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id=\"$pgid\"";
#		my $row = $dbh->selectrow_arrayref($query);
		my $query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id= ? ";
		my $row = $dbh->selectrow_arrayref($query,{},$pgid);

		push @results, {'path' => $row->[0], 'filename' => $row->[1], 'morelt' => $row->[2], 'pgid'=> $row->[3], 'static' => $row->[4], 'MO' => $row->[5] };
		
	}
        $dbh->disconnect;
	return @results;
}
sub getDirListings {

    my $r = shift;
    my $amcounter = shift;
    my $topdir = $r->param('library_topdir');
    my $libraryRoot = $topdir; #$r->param('library_dir')."/".$r->param('library_subdir');
    
    $libraryRoot = $libraryRoot."/".$r->param('library_lib') if($r->param('library_lib') ne $r->maketext("Select Library"));
    $libraryRoot = $libraryRoot."/".$r->param('library_dir') if($r->param('library_dir') ne $r->maketext("All Directories"));
    $libraryRoot = $libraryRoot."/".$r->param('library_subdir') if($r->param('library_subdir') ne $r->maketext("All Subdirectories"));


    my @results = ();
    my $level = 4;
    my @lis;

    eval {
    @lis = File::Find::Rule->file()
                            ->name('*.pg')
                            ->maxdepth($level)
                            ->extras({ follow => 1 })
                            ->in($libraryRoot);
    };
    if($amcounter) {
         return(scalar(@lis));
    }

=comment
    my @lis = eval { readDirectory($topdir) };
    my @pgfiles = grep { m/\.pg$/ and (not m/(Header|-text)(File)?\.pg$/) and -f "$topdir/$_"} @lis;
=cut

    foreach (sort @lis) {
        my $filename = basename($_);
        my $pgpath   = dirname($_);
        $pgpath =~ s|^$topdir/||;
        push @results, {'path' => $pgpath, 'filename' => $filename, 'morelt' => undef, 'pgid'=> $3, 'static' => undef, 'MO' => undef };
    }
    return @results;
}

sub countDBListings {
	my $r = shift;
        my $typ = shift || $r->param('library_srchtype');
        if($typ eq 'BPL') {
	    return (getBPLDBListings($r,1,$typ));
        } elsif($typ eq 'BPLEN') {
	    return (getBPLENDBListings($r,1,$typ));
        } else {
	    return (getDBListings($r,1,$typ));
        }
}
sub countDirListings {
	my $r = shift;
	return (getDirListings($r,1));
}
sub getMLTleader {
	my $r = shift;
	my $mltid = shift;
	my %tables = getTables($r->ce);
	my $dbh = getDB($r->ce);
	my $query = "SELECT leader FROM `$tables{morelt}` WHERE morelt_id=\"$mltid\"";
	my $row = $dbh->selectrow_arrayref($query);
	return $row->[0];
}

##############################################################################
# input expected: keywords,<keywords>,chapter,<chapter>,section,<section>,path,<path>,filename,<filename>,author,<author>,instituition,<instituition>,history,<history>
#
#
# Warning - this function is out of date (but currently unused)
#

# sub createListing {
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my %listing_data = @_; 
# 	my $classify_id;
# 	my $dbh = getDB($ce);
# 	#	my $dbh = WeBWorK::ProblemLibrary::DB::getDB();
# 	my $query = "INSERT INTO classify
# 		(filename,chapter,section,keywords)
# 		VALUES
# 		($listing_data{filename},$listing_data{chapter},$listing_data{section},$listing_data{keywords})";
# 	$dbh->do($query);	 #TODO: watch out for comma delimited keywords, sections, chapters!
# 
# 	$query = "SELECT id FROM classify WHERE filename = $listing_data{filename}";
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	if ($sth->rows())
# 	{
# 		($classify_id) = $sth->fetchrow_array;
# 	}
# 	else
# 	{
# 		#print STDERR "ListingDB::createListingPGfiles: $listing_data{filename} failed insert into classify table";
# 		return 0;
# 	};
# 
# 	$query = "INSERT INTO pgfiles
#    (
#    classify_id,
#    path,
#    author,
#    institution,
#    history
#    )
#    VALUES
#   (
#    $classify_id,
#    $listing_data{path},
#    $listing_data{author},
#    $listing_data{institution},
#    $listing_data{history}
#    )";
# 	
# 	$dbh->do($query);
# 	return 1;
# }

##############################################################################
# input expected any pair of: keywords,<keywords data>,chapter,<chapter data>,section,<section data>,filename,<filename data>,author,<author data>,instituition,<instituition data>
# returns an array of hash references
#
# Warning - out of date (and unusued)
#

# sub searchListings {
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my %searchterms = @_;
# 	#print STDERR "ListingDB::searchListings  input array @_\n";
# 	my @results;
# 	my ($row,$key);
# 	my $dbh = getDB($ce);
# 	my $query = "SELECT c.filename, p.path
# 		FROM classify c, pgfiles p
# 		WHERE c.id = p.classify_id";
# 	foreach $key (keys %searchterms) {
# 		$query .= " AND c.$key = $searchterms{$key}";
# 	};
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	if ($sth->rows())
# 	{
# 		while (1)
# 		{
# 			$row = $sth->fetchrow_hashref();
# 			if (!defined($row))
# 			{
# 				last;
# 			}
# 			else
# 			{
# 				#print STDERR "ListingDB::searchListings(): found $row->{id}\n";
# 				my $listing = $row;
# 				push @results, $listing;
# 			}
# 		}
# 	}
# 	return @results;
# }
##############################################################################
# returns a list of Directories
#
sub getAllDirs {

    my $r = shift;
    my $lib = $r->param('library_lib');
    my $topdir = $r->param('library_topdir');
    my $dir = $r->param('library_dir');
    my $subdir = $r->param('library_subdir');
    my @dirs = ();

    my $path = $topdir.'/'.$lib.'/'.$dir;
    my @lis = eval { readDirectory($path) };
    foreach (sort @lis) {
     next if /^\.+/;
     if(-d "$path/$_") {
       push @dirs, $_ ;
     }
    }
    return @dirs;
    
}
##############################################################################
# returns a list of chapters
#
# Warning - out of date
#

# sub getAllChapters {
# 	#print STDERR "ListingDB::getAllChapters\n";
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my @results=();
# 	my ($row,$listing);
# 	my $query = "SELECT DISTINCT chapter FROM classify";
# 	my $dbh = getDB($ce);
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_array;
# 		if (!defined($row))
# 		{
# 			last;
# 		}
# 		else
# 		{
# 			my $listing = $row;
# 			push @results, $listing;
# 			#print STDERR "ListingDB::getAllChapters $listing\n";
# 		}
# 	}
# 	return @results;
# }
##############################################################################
# input chapter
# returns a list of sections
#
# Warning - out of date (and unused)
#

# sub getAllSections {
# 	#print STDERR "ListingDB::getAllSections\n";
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my $chapter = shift;
# 	my @results=();
# 	my ($row,$listing);
# # 	my $query = "SELECT DISTINCT section FROM classify
# # 				WHERE chapter = \'$chapter\'";
# 	my $query = "SELECT DISTINCT section FROM classify
# 				WHERE chapter = ? ";
# 	my $dbh = getDB($ce);
# #	my $sth = $dbh->prepare($query);
# 	my $sth = $dbh->prepare($query, $chapter);
# 
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_array;
# 		if (!defined($row))
# 		{
# 			last;
# 		}
# 		else
# 		{
# 			my $listing = $row;
# 			push @results, $listing;
# 			#print STDERR "ListingDB::getAllSections $listing\n";
# 		}
# 	}
# 	return @results;
# }

##############################################################################
# returns an array of hash references
#
# Warning - out of date (and unused)
#

# sub getAllListings {
# 	#print STDERR "ListingDB::getAllListings\n";
# 	my $ce = shift;
# 	my @results;
# 	my ($row,$key);
# 	my $dbh = getDB($ce);
# 	my %tables = getTables($ce);
# 	my $query = "SELECT c.*, p.path
# 			FROM classify c, pgfiles p
# 			WHERE c.pgfiles_id = p.pgfiles_id";
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_hashref();
# 		last if (!defined($row));
# 		my $listing = $row;
# 		push @results, $listing;
# 		#print STDERR "ListingDB::getAllListings $listing\n";
# 	}
# 	return @results;
# }

##############################################################################
# input chapter, section
# returns an array of hash references.
# if section is omitted, get all from the chapter
sub getSectionListings	{
	#print STDERR "ListingDB::getSectionListings(chapter,section)\n";
	my $r = shift;
        my $typ = shift || "";
	my $ce = $r->ce;
	my $version = $ce->{problemLibrary}->{version} || 1;
	if($version => 2) { return(getDBListings($r, 0, $typ))}
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";

	my $chapstring = '';
	if($chap) {
		$chap =~ s/'/\\'/g;
		$chapstring = " c.chapter = \'$chap\' AND ";
	}
	my $secstring = '';
	if($sec) {
		$sec =~ s/'/\\'/g;
		$secstring = " c.section = \'$sec\' AND ";
	}

	my @results; #returned
# 	my $query = "SELECT c.*, p.path
# 	FROM classify c, pgfiles p
# 	WHERE $chapstring $secstring c.pgfiles_id = p.pgfiles_id";
# 	my $dbh = getDB($ce);
# 	my %tables = getTables($ce);
# 	my $sth = $dbh->prepare($query);
# 	
# 	$sth->execute();
    my $query = "SELECT c.*, p.path
	FROM classify c, pgfiles p
	WHERE ? ? c.pgfiles_id = p.pgfiles_id";
	my $dbh = getDB($ce);
	my %tables = getTables($ce);
	my $sth = $dbh->prepare($query);
	
	$sth->execute($chapstring,$secstring);

	while (1)
	{
		my $row = $sth->fetchrow_hashref();
		if (!defined($row))
		{
			last;
		}
		else
		{
			push @results, $row;
			#print STDERR "ListingDB::getSectionListings $row\n";
		}
	}
	return @results;
}

###############################################################################
# INPUT:
#  listing id number
# RETURN:
#  1 = all ok
#
# not implemented yet
sub deleteListing {
	my $ce = shift;
	my $listing_id = shift;
	#print STDERR "ListingDB::deleteListing(): listing == '$listing_id'\n";

	my $dbh = getDB($ce);
	my %tables = getTables($ce);

	return undef;
}


# Use sortByName($aref, @b) to sort list @b using parallel list @a.
# Here, $aref is a reference to the array @a

sub indirectSortByName {
	my $aref = shift ;
	my @a = @$aref;
	my @b = @_;
	my %pairs ;
	for my $j (1..scalar(@a)) {
		$pairs{$a[$j-1]} = $b[$j-1];
	}
	my @list = sortByName(undef, @a);
	@list = map { $pairs{$_} } @list;
	return(@list);
}



##############################################################################
1;

__END__

=back

=head1 DESCRIPTION

This module provides access to the database of classify in the
system. This includes the filenames, along with the table of
search terms.

=head1 FUNCTION REFERENCE

=over 4

=item $result = createListing( %listing_data );

Creates a new listing populated with data from %listing_data. On
success, 1 is returned, 0 is returned on failure. The %listing_data
hash has the following format:
=cut

=back

=head1 AUTHOR

Written by Bill Ziemer.
Modified by John Jones.

=cut


##############################################################################
# end of ListingDB.pm
##############################################################################
