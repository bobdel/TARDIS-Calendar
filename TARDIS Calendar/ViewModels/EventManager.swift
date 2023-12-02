//
//  EventManager.swift
//  TARDIS Calendar
//
//  Created by Monty Harper on 10/17/23.
//
//  Captures new events; provides an array of Event view models.
//

import EventKit
import Foundation
import SwiftUI
import UIKit

// Event is a wrapper for EKEvent, Event Kit's raw event Type.
// - Provides a type for each event
// - Provides a unique id for each event
// - Conforms events to Idenditfiable and Comparable protocols
// - Rounds starting time so it can be used as an alternate identification (No two events should start at the same time.)
// - Exposes various other values.

class Event: Identifiable, Comparable {
    
    var event: EKEvent
    var type: String
        
    init(event: EKEvent, type: String) {
        self.event = event
        self.type = type
    }
        
    var id: UUID {
        UUID()
    }
    
    var startDate: Date {
        // Ensures start time is rounded to the minute.
        let components = Timeline.calendar.dateComponents([.year,.month,.day,.hour,.minute], from: event.startDate)
        return Timeline.calendar.date(from: components)!
    }
    var endDate: Date {
        event.endDate
    }
    var title: String {
        event.title
    }
    var calendarTitle: String {
        event.calendar.title
    }
    var calendarColor: Color {
        let cg = event.calendar.cgColor ?? CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        return Color(cgColor: cg)
    }
    var priority: Int {
        if let number = CalendarType(rawValue:type)?.priority() {
            return number
        } else {
            return 0
        }
    }
    
    // Protocol conformance for Comparable
    static func < (lhs: Event, rhs: Event) -> Bool {
        if lhs.startDate < rhs.startDate {
            return true
        } else if lhs.startDate > rhs.startDate {
            return false
        } else {
            return lhs.priority < rhs.priority
        }
    }
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.startDate == rhs.startDate && lhs.priority == rhs.priority
    }
}


// ContentView uses an instance of EventManager to access current events, calendars, and related info.
class EventManager: ObservableObject {
    
    var eventStore = EKEventStore()
    
    @Published var events = [Event]() // Upcoming events for the maximum number of days displayed.
    @Published var isExpanded = [Bool]() // For each event, should the view be rendered as expanded? This is the source of truth for expansion of event views.
    @Published var calendarSet = CalendarSet() // Tracks which of Apple's Calendar App calendars we're drawing events from.
    
    // newEvents temporarily stores newly downloaded events so that events can be replaced with newEvents on the main thread.
    private var newEvents = [Event]()
    
    init() {
        // TODO: - Hardcoding this for now; will need to allow user to set this up
        UserDefaults.standard.set(
            ["BenaDaily": CalendarType.daily.rawValue,
             "BenaMedical": CalendarType.medical.rawValue,
             "BenaMeals": CalendarType.meals.rawValue,
             "BenaSpecial": CalendarType.special.rawValue
            ],
            forKey: "calendars")
        // Sets up initial lists of calendars and events.
        updateCalendarsAndEvents()
        // Notification will update the calendars and events lists any time an event or calendar is changed in the user's Apple Calendar App.
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCalendarsAndEvents), name: .EKEventStoreChanged, object: eventStore)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(eventStore)
    }
    
    @objc func updateCalendarsAndEvents() {
        calendarSet.updateCalendars(eventStore: eventStore) { error in
            if let error = error {
                StateBools.shared.noPermissionForCalendar = (error == CalendarError.permissionDenied)
                StateBools.shared.noCalendarsSelected = (error == CalendarError.noUserDictionary)
            } else {
                StateBools.shared.noPermissionForCalendar = false
                StateBools.shared.noCalendarsSelected = false
                // called closure to ensure calendars will be updated first.
                self.updateEvents()
            }
        }
    }
        
    @objc func updateEvents() {
        
        print("updateEvents was called.")
        // Set up date parameters
        let start = Timeline.minDay
        let end = Timeline.maxDay
        
        // Set up search predicate
        let findEKEvents = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendarSet.calendarsToSearch)
        
        // Save which dates are shown in expanded view.
        let expandedDates = Set(isExpanded.indices.filter({isExpanded[$0]}).map({events[$0].startDate}))
        
        // Store the search results, converting EKEvents to Events, replacing current events.
        newEvents = eventStore.events(matching: findEKEvents).map({ekevent in
            Event(event: ekevent, type: calendarSet.userCalendars[ekevent.calendar.title] ?? "none")
        })
        
        // events has to be updated on the main queue.
        DispatchQueue.main.async {
            self.updateEventsCompletion(expandedDates)
        }
                
    } // End of updateEvents
    
    func updateEventsCompletion(_ expandedDates: Set<Date>) {
        
        events = newEvents
        
        // Filter the results to remove lower priority events scheduled at the same time as higher priority events...
        // TODO: - Test this!
            self.events = self.events.filter({event in
            let sameDate = self.events.filter({$0.startDate == event.startDate})
            return event == sameDate.max()
        })
        
        // Restore dates that are expanded.
            self.isExpanded = self.events.indices.map({expandedDates.contains(self.events[$0].startDate)})
    }
    
    // Called when user taps the background; closes any expanded views.
    func closeAll() {
        print("Close All")
        for i in 0..<isExpanded.count {
            isExpanded[i] = false
        }
    }
    
}
