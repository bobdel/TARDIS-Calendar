//
//  ContentView.swift
//  TARDIS Calendar
//
//  Created by Monty Harper on 7/12/23.
//
//  This is the calendar view. Mostly this is what we see when the app is running.
//

import Foundation
import SwiftUI

struct ContentView: View {
        
    // Access to view models
    @StateObject private var timeline = Timeline.shared
    @StateObject private var eventManager = EventManager()
    @StateObject private var solarEventManager = SolarEventManager()
    @StateObject private var stateBools = StateBools.shared
    
    // State variables
    @State private var inactivityTimer: Timer?
    @State private var currentDay = Timeline.calendar.dateComponents([.day], from: Date())
    
    // Constants that configure the UI. To mess with the look of the calendar, mess with these.
    let yOfLabelBar = 0.17 // y position of date label bar in unit space
    let yOfTimeline = 0.5
    let yOfInfoBox = 0.09
    
    // Timers driving change in the UI
    // May want to refactor for better efficiency
    // Josh says use timeline view?
    let updateTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    let spanTimer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()
    
    // Used to track drag gesture for the one-finger zoom function.
    static private var dragStart = 0.0
    
    
    var body: some View {
        
        GeometryReader { screen in

            // Custom Zoom gesture attaches to the background and event views.
            // Needs to live here inside the geometry reader.
            let oneFingerZoom = DragGesture()
                .onChanged { gesture in
                    // If this is a new drag starting, save the location.
                    if ContentView.dragStart == 0.0 {
                        ContentView.dragStart = gesture.startLocation.x
                    }
                    let width = screen.size.width
                    // Divide by width to convert to unit space.
                    let start = ContentView.dragStart / width
                    let end = gesture.location.x / width
                    // Save the location of this drag for the next event.
                    ContentView.dragStart = gesture.location.x
                    // Drag gesture needs to occur on the future side of now, far enough from now that it doesn't cause the zoom to jump wildly
                    guard end > Timeline.nowLocation + 0.1 && start > Timeline.nowLocation + 0.1 else {
                        return
                    }
                    // This call changes the trailing time in our timeline, if we haven't gone beyond the boundaries.
                    timeline.newTrailingTime(start: start, end: end)

                    // This indicates user interaction, so reset the inactivity timer.
                    stateBools.animateSpan = false
                    inactivityTimer?.invalidate()

                } .onEnded { _ in
                    // When the drag ends, reset the starting value to zero to indicate no drag is happening at the moment.
                    ContentView.dragStart = 0.0
                    // And reset the inactivity timer, since this indicates the end of user interaction.
                    // When this timer goes off, the screen animates back to default zoom position.
                    inactivityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false, block: {_ in
                        stateBools.animateSpan = true
                    })
                }


                // Main ZStack layers background behind all else
            ZStack {

                // Background shows time of day by color
                BackgroundView(timeline: timeline, solarEventManager: solarEventManager)
                    .zIndex(-100)
                // Zoom in and out by changing trailingTime
                    .gesture(oneFingerZoom)
                // Show progress view while background loads.
                
                if stateBools.showProgressView {
                    ProgressView()
                        .position(x: screen.size.width * 0.5, y: screen.size.height * 0.5)
                        .scaleEffect(4)
                }
                
                // Hidden button in upper right hand corner allows caregivers to change preferences.
                Color(.clear)
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
                    .position(x: screen.size.width - 40, y: 40)
                    .onTapGesture(count: 3, perform: {
                        stateBools.showSettingsAlert = true
                    })
                    .alert("Do you want to change the settings?", isPresented: $stateBools.showSettingsAlert) {
                        Button("No - Touch Here to Go Back", role: .cancel, action: {})
                        Button("Yes", action: {stateBools.showSettings = true})
                    }
                    .sheet(isPresented: $stateBools.showSettings) {
                        SettingsView(eventManager: eventManager)
                            .onDisappear {
                                eventManager.updateEvents()
                            }
                    }


                // View on top of background is arranged into three groups; label bar, timeline for events, and banner messages. Grouping is just conceptual, and needed because the are more than ten items in this ZStack. Individual elements are placed exactly.


                Group { // Label Bar

                    // Current Date
                    CurrentDateAndTimeView()
                        .position(x: 0.2 * screen.size.width, y: yOfInfoBox * screen.size.height)

                    // TimeTick Markers
                    ForEach(
                        TimeTick.array(timeline: timeline), id: \.self.xLocation) {tick in
                            TimeTickMarkerView(timeTick: tick)
                                .position(x: screen.size.width * tick.xLocation, y: yOfLabelBar * screen.size.height)
                        }


                    // Label bar background
                    Color(.white)
                        .frame(width: screen.size.width, height: 0.065 * screen.size.height)
                        .position(x: 0.5 * screen.size.width, y: yOfLabelBar * screen.size.height)


                    // TimeTick Labels
                    HorizontalLayoutNoOverlap{
                        ForEach(
                            TimeTick.array(timeline: timeline), id: \.self.xLocation) {tick in
                                TimeTickLabelView(timeTick: tick)
                                    .xPosition(tick.xLocation)
                            }
                    }
                    .position(x: screen.size.width * 0.5, y: yOfLabelBar * screen.size.height)

                } // End of Label Bar


                Group {// Timeline

                    // Background is a horizontal arrow across the screen
                    Color(.black)
                        .shadow(color: .white, radius: 3)
                        .frame(width: screen.size.width, height: 2)
                        .position(x: 0.5 * screen.size.width, y: yOfTimeline * screen.size.height)
                        .zIndex(-90)
                    ArrowView(size: 0.0)
                        .position(x: screen.size.width, y: yOfTimeline * screen.size.height)


                    // Circles representing events along the time line

                    ForEach(eventManager.events.indices.sorted(by: {$0 > $1}), id: \.self) { index in
                        EventView(event: eventManager.events[index], isExpanded: $eventManager.isExpanded[index], shrinkFactor: shrinkFactor(), screenWidth: screen.size.width)
                            .position(x: timeline.unitX(fromTime: eventManager.events[index].startDate.timeIntervalSince1970) * screen.size.width, y: yOfTimeline * screen.size.height)
                    }
                    .gesture(oneFingerZoom)



                    // Circle representing current time.
                    NowView()
                        .position(x: Timeline.nowLocation * screen.size.width, y: yOfTimeline * screen.size.height)


                } // End of Timeline


                AlertView(screen: screen)

                    

            } // End of main ZStack


            // Update timer fires once per second.
                .onReceive(updateTimer) { time in

                    // Advance the timeline
                    timeline.updateNow()
                    print(timeline.now)

                    // Check for new day; update calendar and solar events once per day.
                    let today = Timeline.calendar.dateComponents([.day], from: Date())
                    if today != currentDay {
                        print("called update calendars from new day in contentview")
                        eventManager.updateCalendarsAndEvents()
                        solarEventManager.updateSolarDays(){_ in}
                        currentDay = today
                    }

                }

            // Animating zoom's return to default by hand
                .onReceive(spanTimer) { time in
                    if stateBools.animateSpan {changeSpan()}
                }

            // Tapping outside an event view closes all expanded views
                .onTapGesture {
                    eventManager.closeAll()
                }

        } // End of Geometry Reader
        .ignoresSafeArea()
        .environmentObject(timeline)
        
    } // End of ContentView
    
    
    // This function animates the calendar back to default zoom level.
    func changeSpan() {
        
        // Represents one frame - changes trailingTime toward the default time.
        // Maybe I can get swift to animate this?
        
        if abs(Timeline.defaultSpan - timeline.span) > 1 {
            let newSpan = timeline.span + 0.02 * (Timeline.defaultSpan - timeline.span)
            print(newSpan)
            let newTrailingTime = timeline.leadingTime + newSpan
            timeline.trailingTime = newTrailingTime
            
        } else {
            stateBools.animateSpan = false
        }
        
    }
    
    // This function provides a factor by which to re-size low priority event views, shrinking them as the calendar zooms out. This allows high priority events to stand out from the crowd.
    func shrinkFactor() -> Double {
        
        let x = timeline.span

        // min seconds on screen to trigger shrink effect; set for 8 hours
        let min = 8.0 * 60 * 60
        let max = timeline.maxSpan // seconds on screen where target size is reached
        let b = 0.35 // target size
        
        switch x {
        case 0.0..<min:
            return 1.0
        case min..<max:
            let result = (b - 1) * (x - min)/(max - min) + 1
            return Double(result)
        default:
            return b
        }
        
    }
    
    
}




