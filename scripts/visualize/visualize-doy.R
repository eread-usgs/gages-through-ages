visualize.doy <- function(viz = getContentInfo(viz.id = "doy-NM")){

  library(svglite)
  library(dplyr)
  library(xml2)
    
  daily <- readData(viz[["depends"]][["daily"]])
  zoomer <- readData(viz[["depends"]][["zoomer"]])
  zoomer.xml <- read_xml(zoomer)
  
  height <- viz[["height"]]
  width <- viz[["width"]]
  
  doy_svg = svglite::xmlSVG({
    par(omi=c(0,0,0,0), mai=c(0.5,0.75,0,0),las=1, xaxs = "i")
    plot(1, type="n", xlab="", frame.plot=FALSE,
         ylab="Cubic Feet Per Second", mgp=c(2.5,0.25,0), 
         xlim=c(0, 366), ylim=c(0, 16000),xaxt="n")
    mtext(month.abb, 1, line = -0.5,
          at=c(15,46,74,105,135,166,196,227,258,288,319,349))
  }, height=height, width=width)
  
  #################
  r <- xml_find_all(doy_svg, '//*[local-name()="rect"]')
  
  defs <- xml_find_all(doy_svg, '//*[local-name()="defs"]')
  # !!---- use these lines when we have css for the svg ---!!
  xml_remove(defs)
  
  text <- xml_find_all(doy_svg, '//*[local-name()="text"]')
  xml_attr(text, "style") <- NULL
  xml_attr(text, "textLength") <- NULL
  xml_attr(text, "lengthAdjust") <- NULL
  
  # clean up junk that svglite adds:
  .junk <- lapply(r, xml_remove)

  #################
  xml_name(doy_svg, ns = character()) <- "g"
  xml_attr(doy_svg, "class") <- "axis-labels"

  vb <- xml_attr(doy_svg, "viewBox")
  xml_attr(doy_svg, "viewBox") <- NULL
  
  root <- xml_new_document() %>% xml_add_child("svg")
  xml_add_child(root, doy_svg)
  
  xml_attr(root, "preserveAspectRatio") <- "xMidYMid meet"
  xml_attr(root, "xmlns") <- 'http://www.w3.org/2000/svg'
  xml_attr(root, "xmlns:xlink") <- 'http://www.w3.org/1999/xlink'
  xml_attr(root, "id") <- viz[["id"]]

  xml_add_sibling(xml_children(root)[[1]], 'desc', .where='before', viz[["alttext"]])
  xml_add_sibling(xml_children(root)[[1]], 'title', .where='before', viz[["title"]])
  
  grab_spark <- function(vals, yMax, height, width){
    
    x = svglite::xmlSVG({
      par(omi=c(0,0,0,0), mai=c(0.5,0.75,0,0),
          las=1, mgp=c(2.5,0.25,0), xaxs = "i")
      plot(vals, type='l', axes=F, ann=F,
           xlim=c(0, 366), ylim=c(0, yMax))
    }, height=height, width=width)
    
  }
  
  g.doys <- xml_add_sibling(xml_children(root)[[length(xml_children(root))]], 'g', id='dayOfYear','class'='doy-polyline')
  
  yMax <- max(daily$Flow, na.rm = TRUE)
  maxYear <- viz[["maxYear"]]
  minYear <- viz[["minYear"]]
  
  years <- unique(daily$Year)
  years <- years[years <= maxYear]
  years <- years[years >= minYear]
  
  for(i in years){
    year_data <- filter(daily, Year == i) 

    if((i%%4 == 0) & ((i%%100 != 0) | (i%%400 == 0))){
      year_data$DayOfYear[year_data$DayOfYear>=60] <- year_data$DayOfYear[year_data$DayOfYear>=60]+1
    }
    
    sub_data <- data.frame(approx(year_data$DayOfYear, 
                                  year_data$Flow, n = 366/viz[["full-desample"]]))
    
    x <- grab_spark(sub_data, yMax, height, width)
    polyline <- xml_find_first(x, '//*[local-name()="polyline"]')
    xml_attr(polyline, "id") <- paste0("l",i)
    xml_attr(polyline, "class") <- "doy-lines-by-year"
    xml_attr(polyline, "clip-path") <- NULL
    xml_attr(polyline, "style") <- NULL
    xml_attr(polyline, "viewBox") <- NULL
    xml_add_child(g.doys, polyline)
  }
  
  g.zoomer <- xml_add_sibling(xml_children(root)[[length(xml_children(root))]], 'g', id='total_hydro','class'='total_hydro')
  
  vb <- as.numeric(strsplit(vb, ' ')[[1]])
  xml_attr(g.zoomer, 'transform') <- sprintf("translate(0,%s)", vb[4])

  xml_add_child(g.zoomer, zoomer.xml)
  
  h <- xml_find_all(g.zoomer, '//*[local-name()="rect"]')[1] %>% xml_attr('height') %>% as.numeric() %>% max
  vb[4] <- vb[4] + h*2
  
  xml_attr(root, "viewBox") <- paste(vb, collapse=' ')
  
  write_xml(root, viz[["location"]])
  
}