#!/usr/bin/perl

#########################################################################################
#                         RECURSIVE GIT SUBMODULE UPDATER SCRIPT                        #
#########################################################################################
#   USAGE:                                                                              #
#       cd [<The base Git Working Copy Directory>]                                      #
#       gitsclone.pl [-r] (Operates on the CWD).                                        #
#                                                                                       #
#       ARGUMENTS:                                                                      #
#                   -r  Recursive.  If specified, the operation will work recursively.  #
#                                   Default is one-level only.                          #
#                                                                                       #
#   This script recursively goes through a Git repository working copy, and "drills"    #
#   into submodules. It goes as deep as it can, and ensures that the "deepest" modules  #
#   are updated, prior to "containing" modules being updated.                           #
#                                                                                       #
#   BIG CAVEAT:                                                                         #
#       It's usually not a good idea to circumvent the traditional "waterfall" release  #
#       process. A containing submodule may actually need one of the contained modules  #
#       to be an older version, so this could torpedo that. It's always a good idea to  #
#       manage the release process manually. This is a "quick and dirty" method for an  #
#       active development tree.                                                        #
#                                                                                       #
#   VERSION: 1.0.4                                                                      #
#                                                                                       #
#   1.0.4:  Now operate at the top-level only, unless specifically told to recurse,     #
#           with a -r. Set the init to before the recursion, to ensure that the various #
#           submodules are actually created BEFORE they are checked for embedded.       #
#           submodules (duh).                                                           #
#                                                                                       #
#   1.0.3:  Simplified the system calls.                                                #
#                                                                                       #
#   1.0.2:  Now prevent incomplete modules from being counted (shouldn't happen).       #
#                                                                                       #
#   1.0.1:  Added a last statement to the loop, if there are multiple submodules, this  #
#           is necessary.                                                               #
#########################################################################################

use strict;
use Cwd;

my $global_indent = 0;
print ( 'Searching the base project at "', cwd(), '"' );
init_and_update($ARGV[0]);
print ( "\n" );

exit;

#########################################################################################
# This function is a recursive function that will traverse a submodule hierarchy,       #
# and will update them, from the bottom up.                                             #
#########################################################################################
sub init_and_update
{
    # This is an array that will hold our submodule listing.
	my @submodules;
	# This contains
	
	# First, you must have submodules.
    if ( open ( GITFILE, '.gitmodules' ) )
        {
        my $heading = <GITFILE>;

        # If so, we parse the .gitmodules file, and get the important parts.
        # This is a REAL DUMB parser. It counts on the lines being in a particular order.
        while ( $heading )
            {
            my $pathname;
            my $url;
    
            # The heading is the submodule header (and name).
            chomp ( $heading );
            $heading =~ s/^\s+//;
            $heading =~ s/\s+$//;
            
            # If we have a submodule...
            if ( $heading =~ m/\[submodule / )
                {
                # Strip off the extra
                $heading =~ s/\[submodule "(.*?)"\]/$1/;
                
                # Kinda kludgy, but not too bad. Cycle through the lines, looking for either a path or a url.
                while ( my $nextline = <GITFILE> )
                    {
                    chomp ( $nextline );
                    $nextline =~ s/^\s+//;
                    $nextline =~ s/\s+$//;
                    
                    if ( $nextline =~ m/path\s?=/ )
                        {
                        $pathname = $nextline;
                        $pathname =~ s/path\s?=\s?(.*?)$/$1/;
                        }
                    elsif ( $nextline =~ m/url\s?=/ )
                        {
                        $url = $nextline;
                        $url =~ s/url\s?=\s?(.*?)$/$1/;
                        }
                    else
                        {
                        $heading = $nextline;
                        # That's it for now.
                        last;
                        }
                    }
                
                # Add it to our stack. Has to have all three parts, or it isn't counted.
                if ( $heading && $pathname && $url )
                    {
                    push @submodules, { 'submodule' => $heading, 'pathname' => $pathname, 'url' => $url } ;
                    }
                }
            else    # Anything else gets tested to see if it's a submodule.
                {
                $heading = <GITFILE>;
                }
            }
        
        close ( GITFILE );
        }
        
    # Make sure that we got some submodules.
    if ( @submodules > 0 )
        {
        # List the submodules contained in this directory.

        output_indents();
        print ( "This directory has the following submodules:" );
        
        # The list should be indented.
        $global_indent++;
        for my $index ( 0 .. $#submodules )
            {
            output_indents();
            print ( $index + 1, ') ', $submodules[$index] { 'submodule' } );
            }
        $global_indent--;
        
        # First, update and initialize the Git submodule repository for this working copy.
        # This ensures that the directory has been created.
        print ( "\ngit submodule update --init:\n" );
        print ( `git submodule update --init 2>&1` );
        
        # Now, we simply go through the list, recursing all the way.
        # This ensures that nested submodules are updated BEFORE their containers.
        # However, we only do it if we were given a -r.
        if ( (index ( $_[0], 'r' ) > 0) )
            {
            for my $index ( 0 .. $#submodules )
                {
                # We keep track of where we are.
                my $start_path = cwd();
                # Drop down into the submodule directory.
                chdir ( $submodules[$index] { 'pathname' } );
                output_indents();
                print ( "Looking for submodules under the ", $submodules[$index] { 'submodule' }, " submodule" );
                # Make sure that command line messages are indented.
                $global_indent++;
                # Drill down.
                init_and_update();
                $global_indent--;
                # Back in the box, laddie.
                chdir ( $start_path );
                }
            }
        
        # Now, bring each submodule up to the current master branch revision.
        print ( "\ngit submodule checkout master:\n",`git submodule foreach 'git checkout master' 2>&1` );
        
        output_indents();
        print ( "Updated the submodules in the \"", cwd(), "\" directory" );
        }
    else
        {
        output_indents();
        print ( "No further submodules under this directory" );
        }
}

#########################################################################################
# This simply helps the user to see the hierarchy of the operation.                     #
#########################################################################################
sub output_indents
{
    print ( "\n" );
    
    for my $index ( 0 .. $global_indent )
        {
        print ( "  " );
        }
}