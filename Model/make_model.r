## Ryan Himmelwright
## Honors Thesis
## Make Model Script
library(base)
library(igraph)
library(Matrix)
library(methods)
library(lattice)

################################################################################
############################## Defined Functions ###############################
################################################################################
# Function to Generate Small World Graph
MakeSWPNetwork <- function(dimension,size,nei,p){
  swpGraph <- watts.strogatz.game(dimension,size,nei,p, loops = FALSE, multiple = FALSE)
  return(swpGraph)
}

# Function to Generate an Erdos-Renyi random graph
MakeRandNetwork <- function(dimension, size, nei, swpGraph){
  # Try to make a random graph with the watts.strogatz.game function
  randGraph <- watts.strogatz.game(dimension,size,nei,1,loops = FALSE, multiple = FALSE)
  return(randGraph)
}

# Finds the hubs of a network.
FindHubs <- function(runCount, hubThreshold, swpGraph){
  hubScore  = hub.score(swpGraph) 
  hubValues = hubScore$vector      # Takes just values from hub score
  # Replaces all hubs with a 1, and other vertices with a 0.
  hubMatrix = replace(replace(hubValues,hubValues >= hubThreshold, 1),
                              hubValues < hubThreshold,0)  
  return(hubMatrix)
}

# Returns the number of hubs in the Matrix
HubCounts <- function(hubMatrix){
  count = sum(hubMatrix == 1)
  return(count)
}


# Calculates S^WS for the network.
CalcSws <- function(swpGraph, randGraph){
  # Calculates clustering coefficients of swp and rand graphs
  swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL,
                            isolates="zero")								
  randGamma = transitivity(randGraph, type="global", vids=NULL, weights=NULL,
                           isolates="zero")                         
  gamma = (swpGamma/randGamma) # combines them to get the Gamma value.

  # Calculates the mean minmal path length for swp and corresponding rand graphs
  swpLambda = average.path.length(swpGraph)
  randLambda = average.path.length(randGraph)
  lambda = (swpLambda / randLambda)  # Combines to get the ratio Lambda value

  Sws = (gamma/lambda) # Calculates S^WS from the ratio.
  
  swsList <- list("Sws" = Sws, "swpPathLength" = swpLambda, 
                  "swpClustering" = swpGamma)
  return(swsList)
}

################################################################################
##############################  Models Functions  ##############################
################################################################################

# Random Model Run. Randomly moves edges.
Run_Random_Model <- function(runCount, swpGraph, randGraph,  hubMatrix,
                             timeSteps){
  runLogOutput = paste('run',runCount,'_logOutput.txt', sep="")
  write(paste('step \t hubCount \t Sws \t avg_Path_Length \t Clustering'), 
        file= runLogOutput, append = TRUE, sep=",")
  
  # Loops the model for specified amount of time (timeSteps)
  for ( step in seq(from=1, to=timeSteps, by=1)){
    x  <- sample(1:length(swpGraph), 1)  # X for swp Graph
    xR <- sample(1:length(randGraph), 1) # X for rand graph
    y  <- sample(1:length(swpGraph), 1)  # Y for swp graph
    yR <- sample(1:length(randGraph), 1) # Y for rand graph
    z  <- sample(1:length(swpGraph), 1)  # Z for swp graph
    zR <- sample(1:length(randGraph), 1) # Z for rand graph
    
    # Re-selects x and y if they don't have an edge between them.  
    while( swpGraph[x,y] == 0){
      x<- sample(1:length(swpGraph), 1)
      y<- sample(1:length(swpGraph), 1) 
    }
    # Re-selects xR and yR if they don't have a connecting edge.
    while( randGraph[xR,yR] == 0){
      xR <- sample(1:length(randGraph),1)
      yR <- sample(1:length(randGraph),1)
    }

    swpGraph[x,y]    <- FALSE              # Remove edge between x and y
    randGraph[xR,yR] <- FALSE              # Remove edge between xR and yR

    # Loops new z values until x and z don't have an edge
    while( swpGraph[x,z] == 1){
      z<- sample(1:length(swpGraph), 1)
          }
    while( randGraph[xR,zR] == 1){
      zR <- sample(1:length(randGraph), 1)
    }
    swpGraph[x,z] <- 1                  # Add edge between x and z
    randGraph[xR,zR] <- 1               # Add edge between xR and zR
    
#    print(swpGraph[])
    print(step)
    
    # Print attributes to output file
    # -------------------------------
    swsList = CalcSws(swpGraph,randGraph)
    swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL)
    write(paste(step,'\t',HubCounts(FindHubs(runCount, hubThreshold, swpGraph)),
          '\t', swsList$Sws,'\t', swsList$swpPathLength,'\t',
          swsList$swpClustering), file= runLogOutput, append = TRUE, sep="," )
  }
}

# Run model that attacks the hubs first.
Run_Hubs_Model1 <- function(runCount, swpGraph, randGraph, hubThreshold, 
                           timeSteps){
  # Model Print Out 
  runLogOutput = paste('run',runCount,'_logOutput.txt', sep="")
  write(paste('step \t hubCount \t Sws \t avg_Path_Length \t Clustering'), 
        file= runLogOutput, append = TRUE, sep=",")

 # Returns a list of the vertex number of all the hubs. 
  for(step in seq(from=1, to=timeSteps, by=1)){
    # Swp Hubs
    swpHubMatrix  = FindHubs(runCount, hubThreshold, swpGraph)
    swpHubInd     = (which(swpHubMatrix %in% 1))
    swpNonHubs    <- which(!(1:length(swpHubMatrix) %in% swpHubInd))
    # Rand Hubs
    randHubMatrix = FindHubs(runCount, hubThreshold, randGraph)
    randHubInd    = (which(randHubMatrix %in% 1))
    randNonHubs   <- which(!(1:length(randHubMatrix) %in% randHubInd))

    x  <- sample(swpHubInd, 1)    # Random swp Hub Node
    xR <- sample(randHubInd, 1)   # random rand Hub node
    y  <- sample(swpHubInd, 1)    # Random swp Hub Node
    yR <- sample(randHubInd, 1)   # Random rand Hub node
    z  <- sample(swpNonHubs, 1)   # Random Non-hub  
    zR <- sample(randNonHubs, 1)   # Random rand Hub Node
    
    swpGraph[x,y]    <- FALSE     # Remove connection between swp hubs
    randGraph[xR,yR] <- FALSE     # Remove connection between rand hubs     
    
    # Get a non-x-connected z value for swp graph
    while( swpGraph[x,z] == 1){
      z <- sample(swpNonHubs, 1) 
    } 
    # Get a non-x-connected z value for rand graph
    while( randGraph[xR,zR] == 1){
      zR <- sample(randNonHubs, 1)
    }

    swpGraph[x,z]    <- 1   # Add connection from hub to non hub in swp graph
    randGraph[xR,zR] <- 1   # Add connection from hub to non hub in rand graph      

    print(paste('step: ', step))
      
    # Print attributes to output file
    # -------------------------------
    swsList = CalcSws(swpGraph,randGraph)
    swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL)
    write(paste(step,'\t',HubCounts(FindHubs(runCount, hubThreshold, swpGraph)),
          '\t', swsList$Sws,'\t', swsList$swpPathLength,'\t',
          swsList$swpClustering), file= runLogOutput, append = TRUE, sep="," )
    }
}

# Runs a model that only progresses forward if it increases pathlength.
Run_PathLength_Model <- function(swpGraph, randGraph, hubMatrix){
  # Sets up the output files
  runLogOutput = paste('run',runCount,'_logOutput.txt', sep="")
  write(paste('step \t hubCount \t Sws \t avg_Path_Length \t Clustering'),
        file= runLogOutput, append = TRUE, sep=",")
  
  # Loops the model for specified amount of time (timeSteps)
  for ( step in seq(from=1, to=timeSteps, by=1)){
    print(step)
    old_PathLength = average.path.length(swpGraph)   
    model_Drive = TRUE
    tryCount = 1

    # Drives model until the path length increases  
    while(model_Drive){
      x<- sample(1:length(swpGraph), 1) # random int
      y<- sample(1:length(swpGraph), 1) # random int
      z<- sample(1:length(swpGraph), 1) # random int
    
      # Re-selects x and y if they don't have an edge between them.  
      while( swpGraph[x,y] == 0){
        x <- sample(1:length(swpGraph), 1)
        y <- sample(1:length(swpGraph), 1) 
      }
      swpGraph[x,y] <- FALSE              # Remove edge between x and y
    
      # Loops new z values until x and z don't have an edge
      while( swpGraph[x,z] == 1){
        z <- sample(1:length(swpGraph), 1)
      }
      swpGraph[x,z] <- 1                  # Add edge between x and z
      
      # If new pathlength greater, move to next step.
      if(average.path.length(swpGraph) > old_PathLength){
        model_Drive = FALSE
        print(average.path.length(swpGraph))
        old_PathLength = average.path.length(swpGraph)
      } else {
        print(paste("tryCount: ",tryCount," Step: ", step))
        tryCount = tryCount + 1
      }
   }  
        
    # Print attributes to output file
    # -------------------------------
    swsList = CalcSws(swpGraph,randGraph)
    swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL)
    write(paste(step,'\t',HubCounts(FindHubs(runCount, hubThreshold, swpGraph)),
          '\t', swsList$Sws,'\t', swsList$swpPathLength,'\t',
          swsList$swpClustering), file= runLogOutput, append = TRUE, sep="," )
  }
}


################################################################################
############################## Printing Functions ##############################
################################################################################
PrintGraphStats <- function(runCount, swpGraph, randGraph, hubMatrix,dimension, size,
                            nei, p, hubThreshold){
  # Generate output file of each run in each run directory
  outfileName = "../cumulative_attributes.txt"   
    
  for (i in seq(from=1, to=2, by=1)){
    write(paste('runCount: ', runCount), file= outfileName, append = TRUE, sep= ", ")
    write(paste('dimension: ', dimension), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Size: ',size), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Nei: ', nei), file= outfileName, append = TRUE, sep= ", ")
    write(paste('p: ',p), file= outfileName, append = TRUE, sep= ", ")
    write(paste('hubThreshold: ', hubThreshold), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Vertice count: ', vcount(swpGraph)), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Edge count: ',ecount(swpGraph)), file= outfileName, 
          append = TRUE, sep= ", ")
    write(paste('swpGraph Sws: ', CalcSws(swpGraph, randGraph)$Sws), file= outfileName, append = TRUE, 
          sep= ", ")
    write(paste('swpGraph Hub count: ', sum(hubMatrix == 1)), file= outfileName,
          append = TRUE, sep= ", ")
    write('', file= outfileName, append = TRUE)
    
    outfileName = paste('starting_params.txt', sep="")
    }
}

PlotGraph <- function(runCount, swpGraph, randGraph, hubMatrix){
  # Color hubs in SWP plot.
  for (i in seq(from=1, to= length(hubMatrix), by=1)){
    if(hubMatrix[i] == 1){
      V(swpGraph)$color[i] = "green"
      }
      else{
        V(swpGraph)$color[i] = "cyan"
      }
  }
  ## Plot
  png(file=(paste("SWPplot",runCount,".png",sep="")))
  plot(swpGraph)
  png(file="rand_plot1.png")
  plot(randGraph)
}

################################################################################
################################ Execution Code ################################
################################################################################
args <- commandArgs(trailingOnly = TRUE)
topFolder <- args[1]
name 	  <- args[2]
dimension <- as.numeric(args[3])
size      <- as.numeric(args[4])
nei  	  <- as.numeric(args[5])
p    	  <- as.numeric(args[6])

# Number of runs
trialCount= as.numeric(args[7])
timeSteps = as.numeric(args[8])

setwd(topFolder)


hubThreshold  = 0.8 # The threshold of the centrality score for determing a hub

# Generate Directories for all trials
runCount =1

for( i in seq(from=1, to= trialCount, by=1)){

  print(getwd()) # print current working directory
  
  print(paste('mkdir ',name, sep=""))
  system(paste('mkdir ', name, sep=""))
  setwd(paste(name, sep=""))
  print(getwd())

  #-----------------------------------------------
  #--------------- Model Sequence ----------------
  #-----------------------------------------------

  # Generate Graphs
  # ----------------
  notSWP      = TRUE # true if the graphs are not swp
  notSWPCount = 0
  while(notSWP){
    print("redo")
    notSWPCount = notSWPCount + 1
    print(notSWPCount)
    swpGraph = MakeSWPNetwork(dimension,size,nei,p)
    randGraph = MakeRandNetwork(dimension, size, nei, swpGraph)
    if(CalcSws(swpGraph, randGraph)$Sws > 1) notSWP=FALSE
    if(notSWPCount >= 1000){
	  write(paste('Could not generate SWP graph in ', notSWPCount, 
	  	            ' tries.'), file= 'failed.txt', append = TRUE, sep= ", ")
	  quit(save = "no")
    }
    }    
    

    # Run functions on Graphs
    # ------------------------
    hubMatrix = FindHubs(runCount, hubThreshold, swpGraph)
   # CalcSws = CalcSws(swpGraph, randGraph)
    PrintGraphStats(runCount, swpGraph, randGraph, hubMatrix, dimension, size, nei, p,
                    hubThreshold)
#    plotGraph = PlotGraph(runCount, swpGraph, randGraph, hubMatrix)
#    rand_Model_Run = Run_Random_Model(runCount,swpGraph, randGraph, hubMatrix,
#                                     timeSteps)
 
    hubs_Model_run1 = Run_Hubs_Model1(runCount, swpGraph, randGraph, hubThreshold, 
                           timeSteps)

#    pathLength_Model_Run = Run_PathLength_Model(swpGraph, randGraph, hubMatrix)

    # Increment for next run
    # ----------------------
    runCount = runCount + 1
    setwd("..") # Go up a directory
}
print(warnings())
