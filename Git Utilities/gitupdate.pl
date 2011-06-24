#!/usr/bin/perl

#########################################################################################
#                         RECURSIVE GIT SUBMODULE UPDATER SCRIPT                        #
#########################################################################################
#   USAGE:                                                                              #
#       cd [<POSIX Path to Git Repository>]                                             #
#       gitupdate.pl [-rdhx] (Operates on the CWD).                                     #
#                                                                                       #
#       OR                                                                              #
#                                                                                       #
#       gitupdate.pl [-rdhx] [<POSIX Path to Git Repository>]                           #
#                                                                                       #
#   ARGUMENTS:                                                                          #
#       -r  Recursive   If specified, the operation will update recursively.            #
#                       Default is one-level only.                                      #
#                                                                                       #
#       -d  Delete      Unlinks (deletes) the submodule mapping. Will not work with -r. #
#                                                                                       #
#       -x  HEAD        Checks out the HEAD revisions (See Caveat).                     #
#                                                                                       #
#       -h  Help        Prints the usage info.                                          #
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
#       active development tree. It's useful for testing in an informal way.            #
#                                                                                       #
#   VERSION: 1.0.11                                                                     #
#                                                                                       #
#   This script is written by the fine folks at MAGSHARE (http://magshare.org). There   #
#   are no licensing restrictions, but it would be...unfortunate, if folks wanted to    #
#   claim authorship that did not, in fact, do said authoring.                          #
#   With that being said, the seeds of this script started with work by Chris Jean, as  #
#   explained here:                                                                     #
#       http://chrisjean.com/2009/09/16/recursively-updating-git-submodules/            #
#   A lot of the knowledge to extend this script also came from Mark Longair, here:     #
#       http://longair.net/blog/2010/06/02/git-submodules-explained/                    #
#                                                                                       #
#   CHANGELIST:                                                                         #
#                                                                                       #
#   1.0.11: Now save and reset the CWD, when using a passed-in WD.                      #
#                                                                                       #
#   1.0.10: Improved the directory vetting, and beefed up the comments and help.        #
#                                                                                       #
#   1.0.9:  Added the -x option.                                                        #
#                                                                                       #
#   1.0.8:  Added some credits, and the ability to specify a target directory.          #
#                                                                                       #
#   1.0.7:  There was some general bone-headedness in 1.0.6. This has been de-Homered.  #
#                                                                                       #
#   1.0.6:  Added some command-line options. In particular, the -d option, which will   #
#           delete the submodule[s] at the given level.                                 #
#                                                                                       #
#   1.0.5:  Found a bug, where I forgot to propagate the -r into the recursion.         $
#                                                                                       #
#   1.0.4:  Now operate at the top-level only, unless specifically told to recurse,     #
#           with a -r. Set the init to before the recursion, to ensure that the various #
#           submodules are actually created BEFORE they are checked for embedded.       #
#           submodules (duh). The parsing is now a wee bit more robust.                 #
#                                                                                       #
#   1.0.3:  Simplified the system calls.                                                #
#                                                                                       #
#   1.0.2:  Now prevent incomplete modules from being counted (shouldn't happen).       #
#                                                                                       #
#   1.0.1:  Added a last statement to the loop, if there are multiple submodules, this  #
#           is necessary.                                                               #
#########################################################################################

use strict;         # I'm anal. What can I say?
use Cwd;            # We'll be operating on the working directory.
use Getopt::Std;    # This makes it easier to specify command-line options.

my %options = ();

getopts("hrdx", \%options);

my $global_indent = 0;

if ( defined $options{h} )  # BLUE WIZARD NEEDS CLUE -BADLY.
    {
    print << "EOF";
This script recursively goes through a Git repository working copy, and "drills"
into submodules. It goes as deep as it can, and ensures that the "deepest" modules
are updated, prior to "containing" modules being updated.

USAGE:
  cd [<POSIX Path to Git Repository>]
  gitupdate.pl [-rdhx] (Operates on the CWD).
  
  OR
  
  gitupdate.pl [-rdhx] [<POSIX Path to Git Repository>]

ARGUMENTS:
  -r  Recursive   If specified, the operation will update recursively.
                  Default is one-level only.

  -d  Delete      Unlinks (deletes) the submodule mapping. Will not work with -r.

  -x  HEAD        Checks out the HEAD revisions (See Caveat).
  
  -h  Help        Prints the usage info.

BIG CAVEAT:
    It's usually not a good idea to circumvent the traditional "waterfall" release
    process. A containing submodule may actually need one of the contained modules
    to be an older version, so this could torpedo that. It's always a good idea to
    manage the release process manually. This is a "quick and dirty" method for an
    active development tree. It's useful for testing in an informal way.
    
EXAMPLES:
    Just update one repository level at the working directory:
    
        cd /usr/gitrep/MyVeryKewlGitProject
        /bin/gitupdate.pl
    
    Update a recursive repository at the working directory:
    
        cd /usr/gitrep/MyVeryKewlGitProject
        /bin/gitupdate.pl -r
    
    Delete a repository's submodule references at the working directory:
    
        cd /usr/gitrep/MyVeryKewlGitProject
        /bin/gitupdate.pl -d
    
    Recursively update to HEAD, at a specified directory:
    
        /bin/gitupdate.pl -rx /usr/gitrep/MyVeryKewlGitProject
EOF
    }
else
    {
    my $old_cwd = cwd();    # Save for after
    
    # Check to see if the supplied directory is a Git repository.
    if ( defined $ARGV[0] && (-d $ARGV[0] . "/.git") )
        {
        print ( 'Switching the working directory to ', $ARGV[0], ".\n" );
        chdir ( "$ARGV[0]" );
        }
    elsif ( (defined $ARGV[0] && !(-d $ARGV[0] . "/.git")) || !(-d cwd() . "/.git") )
        {
        # We tell the user they handed us a red herring.
        my $dir = cwd();
        
        if ( defined $ARGV[0] && !(-d $ARGV[0] . "/.git") )
            {
            $dir = $ARGV[0];
            }
        
        print ( '"', $dir, '"', " is not a Git repository.\n" );
        exit;
        }
    
    print ( 'Searching the base project at "', cwd(), '"' );
    init_and_update();
    print ( "\n" );
    
    chdir ( $old_cwd ); # Make like a Boy Scout. Leave it better than you found it...
    }

exit;

#########################################################################################
# This function is a recursive function that will traverse a submodule hierarchy,       #
# and will update them, from the bottom up.                                             #
#########################################################################################
sub init_and_update()
{
    # This is an array that will hold our submodule listing.
    my @submodules;
    
    # First, you must have submodules. The .gitmodules file is available if there are modules.
    if ( open ( GITFILE, '.gitmodules' ) )
        {
        my $heading = <GITFILE>;

        # If so, we parse the .gitmodules file, and get the important parts.
        # This is a REAL DUMB parser.
        while ( $heading )
            {
            my $pathname;
            my $url;
    
            # The heading is the submodule header (and name).
            chomp ( $heading );
            # Trim the line.
            $heading =~ s/^\s+//;
            $heading =~ s/\s+$//;
            
            # If we have a submodule...
            if ( $heading =~ m/\[submodule / )
                {
                # Strip off the extra. Keep the name for display.
                $heading =~ s/\[submodule "(.*?)"\]/$1/;
                
                # Kinda kludgy, but not too bad. Cycle through the lines, looking for either a path or a url.
                while ( my $nextline = <GITFILE> )
                    {
                    chomp ( $nextline );
                    # Trim the line.
                    $nextline =~ s/^\s+//;
                    $nextline =~ s/\s+$//;
                    
                    # Look for either a pathname or a URL. Anything else is ignored, but a submodule breaks the loop.
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
                        # Submodule breaks the loop.
                        if ( $nextline =~ m/\[submodule / )
                            {
                            $heading = $nextline;
                            last;
                            }
                        }
                    }
                
                # Add it to our stack. Has to have all three parts, or it isn't counted.
                if ( $heading && $pathname && $url )
                    {
                    push @submodules, { 'submodule' => $heading, 'pathname' => $pathname, 'url' => $url } ;
                    }
                }
            # Anything else gets tested to see if it's a submodule.
            else
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
        
        # If we were given a -d, we simply delete the .gitmodules file, and scrag the script.
        if ( defined $options{d} )
            {
            unlink ( ".gitmodules" );
            output_indents();
            print ( "Deleted Git references to submodules under the ", cwd(), " directory\n" );
            exit;
            }
        else
            {
            # First, update and initialize the Git submodule repository for this working copy.
            # This ensures that the directory has been created.
            # I split these up, because the command line call can be a bit lengthy.
            print ( "\ngit submodule update --init:\n" );
            print ( `git submodule update --init 2>&1` );
            
            # Now, we simply go through the list, recursing all the way.
            # This ensures that nested submodules are updated BEFORE their containers.
            # However, we only do it if we were given a -r.
            if ( defined $options{r} )
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
                    init_and_update();  # Add the '-r' parameter by default.
                    $global_indent--;
                    # Back in the box, laddie.
                    chdir ( $start_path );
                    }
                }
            
            # Now, bring each submodule up to the current master (or HEAD) branch revision.
            
            # If we specify the -x option, then we check out the HEAD revision. Master branch revision is default.
            if ( defined $options{x} )
                {
                output_indents();
                print ( "Checking out the HEAD revision.\n" );
                print ( `git submodule foreach 'git checkout HEAD' 2>&1` );
                }
            else
                {
                print ( "Checking out the master revision.\n" );
                print ( `git submodule foreach 'git checkout master' 2>&1` );
                }
            
            output_indents();
            print ( "Updated the submodules in the \"", cwd(), "\" directory" );
            }
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
sub output_indents()
{
    print ( "\n" );
    
    for my $index ( 0 .. $global_indent )
        {
        print ( "  " );
        }
}