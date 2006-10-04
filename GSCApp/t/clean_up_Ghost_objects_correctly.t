#!/gsc/bin/perl

# Test script for App::DB::TableRow and App::Object
# Copyright (C) 2003 Washington University Genome Sequencing Center
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use warnings;                  
use strict;                  

use GSCApp;
#use Test::Simple tests => 10;
#use GSCApp::Test tests => 10;
use GSCApp::Test;

use Data::Dumper;
use IO::File;
use IO::Handle;

STDOUT->autoflush;
STDERR->autoflush;

App::DB->db_access_level('rw');
App->init();

if(App::DB->db_variant() ne 'development') {
    plan skip_all => "Not safe for production";
} else {
    plan tests => 10;
}

#I wanted a generic table that I could perform a delete action on (but not ACTUALLY
#deleting it), without having to worry about dependencies from other tables on that
#table.  After some thinking, I decided on the QStats table, for no good reason
#except that it works.  But this can be changed to some other table, I'm sure.

#First, we need a qstat entry.  Let's grab the last one entered, for no good reason.
my $max_qstat_id_query=qq(select max(qst_id)
			  from qstats);
my $mqi_sth=App::DB->dbh()->prepare($max_qstat_id_query);
$mqi_sth->execute();
my ($max_qstat_id)=$mqi_sth->fetchrow_array();
ok($max_qstat_id, "Got the max qst_id");

my $qstat=GSC::QStat->get($max_qstat_id);
ok($qstat, "Got the qstat object");

my @all_qstat_objects=GSC::QStat->all_objects_loaded();
ok(@all_qstat_objects==1, "Found one QStat object via the all_objects_loaded() method");
undef @all_qstat_objects;

$qstat->delete();
undef $qstat;

my @all_ghost_qstat_objects=GSC::QStat::Ghost->all_objects_loaded();
ok(@all_ghost_qstat_objects==1, "Found one ghost QStat object via the all_objects_loaded() method");
#print join(" ", $all_ghost_qstat_objects[0]->inheritance()), "\n";
undef @all_ghost_qstat_objects;

App::DB->sync_database();
App::DB->rollback;

@all_ghost_qstat_objects=GSC::QStat::Ghost->all_objects_loaded();
ok(@all_ghost_qstat_objects==0, "Found no ghost QStat objects via the all_objects_loaded() method");
#print Dumper(@all_ghost_qstat_objects);
undef @all_ghost_qstat_objects;

#Now, we want to test commit.  To do this, we'll have to delete something...which I don't like doing.
#SOOOOO...I'm going to create a random dna_pse link, then delete it.  It's the development database,
#so it shouldn't be too bad...but keep it in mind.

my $max_dna_query=qq(select max(dna_id)
		     from dna);
my ($max_dna_id)=App::DB->dbh()->selectrow_array($max_dna_query);
ok($max_dna_id, "Got max dna_id");

my $max_pse_query=qq(select max(pse_id)
		     from process_step_executions pse);
my ($max_pse_id)=App::DB->dbh()->selectrow_array($max_pse_query);
ok($max_pse_id, "Got max pse_id");

my @current_dna_pses=GSC::DNAPSE->get(dna_id => $max_dna_id,
				      pse_id => $max_pse_id);
my @current_dl_ids=map {$_->dl_id()} @current_dna_pses;
#print qq(\@current_dl_ids: size : ).@current_dl_ids.qq( content: @current_dl_ids\n);
my $choose_dl_id_query=qq(select dl_id
			  from dna_location);
if(@current_dl_ids) {
    $choose_dl_id_query.=qq(\nwhere dl_id NOT IN \().join(", ", @current_dl_ids).qq(\));
}
my ($dl_id)=App::DB->dbh()->selectrow_array($choose_dl_id_query);

my %creation_info=(dna_id => $max_dna_id,
		   pse_id => $max_pse_id,
		   dl_id  => $dl_id);

our $dna_pse=GSC::DNAPSE->create(%creation_info);
ok($dna_pse, "Was able to create a dna_pse with info ".join (" ", %creation_info));

App::DB->sync_database();
App::DB->commit();
#system(qq(sqlrun "select * from dna_pse where pse_id = $max_pse_id\n" --db=development));
$dna_pse->unload();
#GSC::DNAPSE->unload();
$dna_pse=undef;

$dna_pse=GSC::DNAPSE->get(%creation_info);
ok($dna_pse, "Got that dna_pse just created okay");

$dna_pse->delete();
$dna_pse=undef;
App::DB->sync_database();
App::DB->commit();

my @ghost_dna_pse=GSC::DNAPSE::Ghost->all_objects_loaded();
ok(@ghost_dna_pse==0, "Found no ghost DNAPSE objects via the all_objects_loaded() method");

# $Header$
