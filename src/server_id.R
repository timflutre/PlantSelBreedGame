## Copyright 2015,2016,2017,2018,2019 Institut National de la Recherche Agronomique
## and Montpellier SupAgro.
##
## This file is part of PlantBreedGame.
##
## PlantBreedGame is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## PlantBreedGame is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public
## License along with PlantBreedGame.  If not, see
## <http://www.gnu.org/licenses/>.


## server for "identification"

## Function
source("src/func_id.R", local=TRUE, encoding = "UTF-8")$value



## get breeder list and create select input ----
breederList <- reactive({
  getBreederList(dbname=setup$dbname)
})
output$selectBreeder <- renderUI({
  selectInput("breederName", "Breeder", choices=as.list(breederList()))

})



## log in ----
accessGranted <- eventReactive(input$submitPSW,
                               ignoreNULL=FALSE,{
   # The access is granted if this conditions are true:
   # 1. the md5 sum of the given password match with the one in the data base
   #    and doesn't correspond to the empty string;
   # 2. the size of "data" folder is under the maximum disk usage limit.
   # If any condition is false, a javascript "alert" will show up explaining why
   # it is not possible to log in.
   #
   # EXCEPTIONS:
   # * The game master can log in even if the second condition is false,
   # but the javascript "alert" will explain that the server is full.
   # * A "tester" is the only status allowed to have an empty password.

   if (input$submitPSW==0){# no pswd given
       return(FALSE)
   }

   # 1. get breeder status
   status <- getBreederStatus(setup$dbname, input$breederName)

   # 2. check given password
   db <- dbConnect(SQLite(), dbname=setup$dbname)
   tbl <- "breeders"
   query <- paste0("SELECT h_psw FROM ", tbl, " WHERE name = '", input$breederName,"'")
   hashPsw <- dbGetQuery(conn=db, query)[,1]
   dbDisconnect(db)
   if(status == "tester"){
     goodPswd <- TRUE
   } else{
     if(input$psw == ""){
       goodPswd <- FALSE
       alert("Error: don't use the empty string as password")
     }
     else if(hashPsw == digest(input$psw, "md5", serialize=FALSE)){
       goodPswd <- TRUE
     } else{
       goodPswd <- FALSE
       alert("Error: wrong password")
     }
   }

   # 3. check disk usage
   if(goodPswd){
       withProgress({
           # get maxDiskUsage
           db <- dbConnect(SQLite(), dbname=setup$dbname)
           tbl <- "breeders"
           query <- paste0("SELECT value FROM constants WHERE item = 'max.disk.usage'")
           maxDiskUsage <- as.numeric(dbGetQuery(conn=db, query)[,1])
           dbDisconnect(db)

           allDataFiles <- list.files("data", all.files=TRUE, recursive=TRUE)
           currentSize <- sum(file.info(paste0("data/", allDataFiles))$size) /
             10^9 # in Gb

           if(currentSize < maxDiskUsage){
               goodDiskUsage <-TRUE
           }else if(status != "game master"){
               goodDiskUsage <-FALSE
               alert("Sorry, the game is currently not available because of disk usage.\nPlease contact your game master to figure out what to do.")
           }else{
               goodDiskUsage <-TRUE
               alert(paste0("Warning! The size of the \"data\" folder exceeds the specified limit\n",
                            paste("of",round(currentSize,2),"Gb (maximum size allowed:",maxDiskUsage,"Gb).\n"),
                            "To preserve your server, players can't log in anymore (but connected users can still play).\n",
                            "If you want to resume the game, please raise the maximum disk usage limit.\n",
                            "Go to the Admin tab, then \"Disk usage\", and raise the threshold."))
           }
       },message = "Connecting...")
   }else{
       # the game master can always log in
       goodDiskUsage <- TRUE
   }

   # 4. output
   if (goodPswd & goodDiskUsage){
     removeUI("#logInDiv")
     return (TRUE)
   } else
     return(FALSE)
})


breeder <- reactive({
  if (accessGranted()){
    input$breederName
  } else
    "No Identification"
})

breederStatus <- reactive({
  if(accessGranted()){
    return(getBreederStatus(setup$dbname, input$breederName))
  } else
    return("No Identification")
})

budget <- reactive({
  input$leftMenu
  input$requestGeno
  if (breeder()!="No Identification"){

    db <- dbConnect(SQLite(), dbname=setup$dbname)
    tbl <- "log"
    query <- paste0("SELECT * FROM ", tbl, " WHERE breeder='", breeder(), "'")
    res <- dbGetQuery(conn=db, query)
    dbDisconnect(db)

    if (nrow(res)>0){
      funApply <- function(x){
        prices[x[3]][[1]]*as.integer(x[4])
      }
      expenses <- sum(apply(res, MARGIN = 1, FUN = funApply))
    }else{expenses <- 0}

    iniTialBuget <- constants$cost.pheno.field*constants$nb.plots*10*1.3
    return(round(iniTialBuget-expenses,2))

  }
})



## Call ui_id_loggedIn.R ----
output$userAction <- renderUI({
  if(accessGranted()){
      source("src/ui_id_loggedIn.R", local=TRUE, encoding="UTF-8")$value
  }
})




## download files ----
# list of avaiable files (this must be reactive value to be refresh)
phenoFiles <- reactive({
  input$leftMenu
  getDataFileList(type="pheno", breeder=breeder())
})
genoFiles <- reactive({
  input$leftMenu
  choices=getDataFileList(type="geno", breeder=breeder())
})
pltMatFiles <- reactive({
  input$leftMenu
  choices=getDataFileList(type="pltMat", breeder=breeder())
})
requestFiles <- reactive({
  input$leftMenu
  choices=getDataFileList(type="request", breeder=breeder())
})


# dwnl buttons ----
output$dwnlPheno <- downloadHandler(
  filename=function () input$phenoFile, # lambda function
  content=function(file){
    initFiles <- list.files("data/shared/initial_data/")
    if (input$phenoFile %in% initFiles) {
      folder <- "data/shared/initial_data"
    } else {
      folder <- paste0("data/shared/",breeder())
    }
    filePath <- paste0(folder, "/", input$phenoFile)
    file.copy(filePath, file)
  }
)

output$dwnlGeno <- downloadHandler(
  filename=function () input$genoFile, # lambda function
  content=function(file){
    initFiles <- list.files("data/shared/initial_data/")
    if (input$genoFile %in% initFiles) {
      folder <- "data/shared/initial_data"
    } else {
      folder <- paste0("data/shared/",breeder())
    }
    filePath <- paste0(folder, "/", input$genoFile)
    file.copy(filePath, file)
  }
)

output$dwnlPltMat <- downloadHandler(
  filename=function () input$pltMatFile, # lambda function
  content=function(file){
    initFiles <- list.files("data/shared/initial_data/")
    if (input$pltMatFile %in% initFiles) {
      folder <- "data/shared/initial_data"
    } else {
      folder <- paste0("data/shared/",breeder())
    }
    filePath <- paste0(folder, "/", input$pltMatFile)
    file.copy(filePath, file)
  }
)


output$dwnlRequest <- downloadHandler(
  filename=function () input$requestFile, # lambda function
  content=function(file){
    initFiles <- list.files("data/shared/initial_data/")
    if (input$requestFile %in% initFiles) {
      folder <- "data/shared/initial_data"
    } else {
      folder <- paste0("data/shared/",breeder())
    }
    filePath <- paste0(folder, "/", input$requestFile)
    file.copy(filePath, file)
  }
)

# UI of dwnl buttons ----
output$UIdwnlPheno <- renderUI({
  if (input$phenoFile!=""){
    if (breederStatus()=="player" && !availToDwnld(input$phenoFile,currentGTime())$isAvailable ){
      p(paste0("Sorry, your data are not available yet. Delivery date: ",
               availToDwnld(input$phenoFile,currentGTime())$availDate))
    }else{
      downloadButton("dwnlPheno", "Download your file")
    }

  }else p("No file selected.")

})

output$UIdwnlGeno <- renderUI({
  if (input$genoFile!=""){
    if (breederStatus()=="player" && !availToDwnld(input$genoFile,currentGTime())$isAvailable ){
      p(paste0("Sorry, your data are not available yet. Delivery date: ",
               availToDwnld(input$genoFile,currentGTime())$availDate))
    }else{
           downloadButton("dwnlGeno", "Download your file")

    }
  }else p("No file selected.")
})

output$UIdwnlPltMat <- renderUI({
  if (input$pltMatFile!=""){
    downloadButton("dwnlPltMat", "Download your file")
  }else p("No file selected.")

})

output$UIdwnlRequest <- renderUI({
  if (input$requestFile!=""){
    downloadButton("dwnlRequest", "Download your file")
  }else p("No file selected.")

})


## My plant-material ----
myPltMat <- reactive({
  if (input$leftMenu=="id"){
    db <- dbConnect(SQLite(), dbname=setup$dbname)
    tbl <- paste0("plant_material_", breeder())
    stopifnot(tbl %in% dbListTables(db))
    query <- paste0("SELECT * FROM ", tbl)
    res <- dbGetQuery(conn=db, query)
    # disconnect db
    dbDisconnect(db)
    res$avail_from <- strftime(res$avail_from, format= "%Y-%m-%d")
    DT::datatable(res,options = list(lengthMenu = c(10, 20, 50),
                                     pageLength = 10,
                                     searchDelay = 500))

  }
})

output$myPltMatDT <- DT::renderDataTable(myPltMat())







## Change Password ----
pswChanged <- eventReactive(input$"changePsw", {
  db <- dbConnect(SQLite(), dbname=setup$dbname)
  tbl <- "breeders"
  query <- paste0("SELECT h_psw FROM ", tbl, " WHERE name = '", input$breederName,"'")
  hashPsw <- dbGetQuery(conn=db, query)[,1]
  dbDisconnect(db)
  if (digest(input$prevPsw, "md5", serialize = FALSE)==hashPsw){
    newHashed <- digest(input$newPsw, "md5", serialize = FALSE)

    db <- dbConnect(SQLite(), dbname=setup$dbname)
    tbl <- "breeders"
    query <- paste0("UPDATE ", tbl, " SET h_psw = '", newHashed,"' WHERE name = '", breeder(), "'" )
    dbExecute(conn=db, query)
    dbDisconnect(db)

    return(TRUE)

  }else {return(FALSE)}

})

output$UIpswChanged <- renderUI({
  if(pswChanged()){
    p("Password Updated")
  } else if (!pswChanged()){
    p("Wrong password, try again")
  }

})



## Breeder information :
output$breederBoxID <- renderValueBox({
  valueBox(
    value = breeder(),
    subtitle = paste("Status:", breederStatus()),
    icon = icon("user-o"),
    color = "yellow"
  )
})

output$dateBoxID <- renderValueBox({
  valueBox(
    subtitle = "Date",
    value = strftime(currentGTime(), format= "%d %b %Y"),
    icon = icon("calendar"),
    color = "yellow"
  )
})



output$budgetBoxID <- renderValueBox({
  valueBox(
    value = budget(),
    subtitle = "Budget",
    icon = icon("credit-card"),
    color = "yellow"
  )
})

output$serverIndicID <- renderValueBox({
  ## this bow will be modified by some javascript
  valueBoxServer(
    value = "",
    subtitle = "Server load",
    icon = icon("server"),
    color = "yellow"
  )
})

output$UIbreederInfoID <- renderUI({
  if (breeder()!="No Identification"){
    list(infoBoxOutput("breederBoxID", width = 3),
         infoBoxOutput("dateBoxID", width = 3),
         infoBoxOutput("budgetBoxID", width = 3),
         infoBoxOutput("serverIndicID", width = 3))
  }

})









# DEBUG

output$IdDebug <- renderPrint({
  print("----")
  print(input$phenoFile)
  print(input$genoFile)
})
