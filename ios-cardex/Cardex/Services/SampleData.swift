import Foundation

/// Development seed content for the prototype: a fixed cast of people, rooms
/// and posts used ONLY to populate the local mock repositories on first
/// launch. Nothing here is real user data, and a production backend replaces
/// every call site. Do not extend the app's runtime logic from this file.
nonisolated enum SampleData {
    static func makeOwner() -> BusinessCard {
        BusinessCard(
            name: "Maya Chen",
            title: "Product Design Lead",
            company: "Nova Systems",
            industry: "Design",
            tagline: "People. Products. Brighter tomorrows.",
            location: "San Francisco, CA",
            photoName: "woman_business_portrait",
            palette: .slate,
            monogram: "MC",
            details: [
                ContactDetail(kind: .mobile, value: "+1 415 555 0142", tier: .trusted),
                ContactDetail(kind: .email, value: "maya@novasystems.com", tier: .connected),
                ContactDetail(kind: .website, value: "mayachen.design", tier: .publicTier),
                ContactDetail(kind: .linkedin, value: "/in/mayachen", tier: .publicTier),
                ContactDetail(kind: .instagram, value: "@maya.builds", tier: .connected)
            ],
            credentials: ["MFA Interaction Design, RISD", "IDSA Design Award 2024"],
            skills: ["Design systems", "Research", "Prototyping", "Team leadership"],
            visibility: .live,
            stories: [
                StoryUpdate(
                    imageName: "warehouse_networking_event",
                    caption: "Great crowd at the mixer tonight.",
                    postedAt: Date().addingTimeInterval(-3 * 3600)
                )
            ]
        )
    }

    /// Development seed for the message inbox, used only by
    /// LocalMessageRepository on first launch.
    static func makeSeedMessages(ownerID: UUID) -> [Message] {
        let contacts = makeContacts()
        let sarah = contacts[0]
        let daniel = contacts[1]
        let tom = contacts[6]

        return [
            Message(
                senderID: sarah.id,
                recipientID: ownerID,
                text: "Loved the rebrand sketch you showed me — still thinking about that type choice.",
                sentAt: Date().addingTimeInterval(-3 * 3600)
            ),
            Message(
                senderID: ownerID,
                recipientID: sarah.id,
                text: "Thanks! Rough night on the kerning, but it came together.",
                sentAt: Date().addingTimeInterval(-2.7 * 3600)
            ),
            Message(
                senderID: sarah.id,
                recipientID: ownerID,
                text: "Coffee next week? I'll bring the printed samples.",
                sentAt: Date().addingTimeInterval(-2.4 * 3600)
            ),
            Message(
                senderID: tom.id,
                recipientID: ownerID,
                text: "Sending over that analytics intro — worth a chat before Q4 planning.",
                sentAt: Date().addingTimeInterval(-30 * 3600)
            ),
            Message(
                senderID: daniel.id,
                recipientID: ownerID,
                text: "Your sync talk got me thinking — CRDTs or last-write-wins?",
                sentAt: Date().addingTimeInterval(-20 * 3600)
            ),
            Message(
                senderID: ownerID,
                recipientID: daniel.id,
                text: "Mostly LWW with tombstones. Conflicts are rare at our scale.",
                sentAt: Date().addingTimeInterval(-19 * 3600)
            )
        ]
    }

    static func makeContacts() -> [BusinessCard] {
        [
            BusinessCard(
                name: "Sarah Okafor",
                title: "Creative Director",
                company: "Studio OK",
                industry: "Brand & Design",
                tagline: "People. Ideas. Brand experiences.",
                location: "London, UK",
                photoName: "woman_curly_hair_portrait",
                palette: .sand,
                monogram: "SO",
                details: [
                    ContactDetail(kind: .mobile, value: "+44 7700 900123", tier: .trusted),
                    ContactDetail(kind: .email, value: "sarah@studio-ok.com", tier: .connected),
                    ContactDetail(kind: .instagram, value: "@sarahokafor", tier: .publicTier),
                    ContactDetail(kind: .linkedin, value: "/in/sarahokafor", tier: .publicTier),
                    ContactDetail(kind: .website, value: "studio-ok.com", tier: .publicTier)
                ],
                credentials: ["D&AD Pencil, 2023", "BA Graphic Design, Central Saint Martins"],
                skills: ["Art direction", "Identity", "Campaigns"],
                visibility: .publicMode,
                stories: [
                    StoryUpdate(
                        imageName: "design_studio_meetup",
                        caption: "Studio walls finally finished.",
                        postedAt: Date().addingTimeInterval(-5 * 3600)
                    ),
                    StoryUpdate(
                        imageName: "rooftop_gathering_dusk",
                        caption: "Rooftop review session.",
                        postedAt: Date().addingTimeInterval(-9 * 3600)
                    )
                ]
            ),
            BusinessCard(
                name: "Daniel Ruiz",
                title: "Staff Engineer",
                company: "Meridian Labs",
                industry: "Software",
                tagline: "Systems that stay simple as they grow.",
                location: "Austin, TX",
                photoName: "latino_man_portrait_sweater",
                palette: .graphite,
                monogram: "DR",
                details: [
                    ContactDetail(kind: .mobile, value: "+1 512 555 0188", tier: .trusted),
                    ContactDetail(kind: .email, value: "daniel@meridianlabs.io", tier: .connected),
                    ContactDetail(kind: .linkedin, value: "/in/danielruiz", tier: .publicTier),
                    ContactDetail(kind: .x, value: "@druiz_dev", tier: .publicTier)
                ],
                credentials: ["BS Computer Science, UT Austin"],
                skills: ["Distributed systems", "Swift", "Platform"],
                visibility: .privateMode
            ),
            BusinessCard(
                name: "James Park",
                title: "Investment Associate",
                company: "Harbourline Capital",
                industry: "Venture Capital",
                tagline: "Backing early teams with unreasonable focus.",
                location: "New York, NY",
                photoName: "korean_man_portrait",
                palette: .indigo,
                monogram: "JP",
                details: [
                    ContactDetail(kind: .mobile, value: "+1 212 555 0119", tier: .trusted),
                    ContactDetail(kind: .email, value: "james@harbourline.com", tier: .trusted),
                    ContactDetail(kind: .linkedin, value: "/in/jamespark", tier: .publicTier)
                ],
                credentials: ["MBA, Columbia Business School"],
                skills: ["Seed investing", "Market analysis"],
                visibility: .privateMode
            ),
            BusinessCard(
                name: "Elena Vasquez",
                title: "Growth Lead",
                company: "Fin+",
                industry: "Fintech",
                tagline: "Turning first users into habits.",
                location: "London, UK",
                photoName: "latina_woman_portrait",
                palette: .clay,
                monogram: "EV",
                details: [
                    ContactDetail(kind: .mobile, value: "+44 7700 900456", tier: .trusted),
                    ContactDetail(kind: .email, value: "elena@finplus.co", tier: .connected),
                    ContactDetail(kind: .instagram, value: "@elena.grows", tier: .publicTier),
                    ContactDetail(kind: .linkedin, value: "/in/elenavasquez", tier: .publicTier)
                ],
                credentials: ["MSc Economics, LSE"],
                skills: ["Lifecycle", "Experimentation", "Paid growth"],
                visibility: .live,
                stories: [
                    StoryUpdate(
                        imageName: "founders_breakfast_cafe",
                        caption: "Breakfast with the Fin+ crew.",
                        postedAt: Date().addingTimeInterval(-2 * 3600)
                    )
                ]
            ),
            BusinessCard(
                name: "Marcus Webb",
                title: "Founder",
                company: "Loop",
                industry: "Software",
                tagline: "Small team, sharp product.",
                location: "London, UK",
                photoName: "professional_editorial_portrait",
                palette: .sage,
                monogram: "MW",
                details: [
                    ContactDetail(kind: .mobile, value: "+44 7700 900781", tier: .trusted),
                    ContactDetail(kind: .email, value: "marcus@loop.app", tier: .connected),
                    ContactDetail(kind: .linkedin, value: "/in/marcuswebb", tier: .publicTier),
                    ContactDetail(kind: .website, value: "loop.app", tier: .publicTier)
                ],
                credentials: ["Y Combinator W24"],
                skills: ["Product", "Fundraising", "Hiring"],
                visibility: .live,
                stories: [
                    StoryUpdate(
                        imageName: "warehouse_networking_event",
                        caption: "Loop team out in Shoreditch.",
                        postedAt: Date().addingTimeInterval(-6 * 3600)
                    )
                ]
            ),
            BusinessCard(
                name: "Priya Nair",
                title: "Partner",
                company: "Arc Capital",
                industry: "Venture Capital",
                tagline: "Early cheques, long patience.",
                location: "London, UK",
                photoName: "venture_capital_investor_woman",
                palette: .slate,
                monogram: "PN",
                details: [
                    ContactDetail(kind: .mobile, value: "+44 7700 900902", tier: .trusted),
                    ContactDetail(kind: .email, value: "priya@arccapital.vc", tier: .trusted),
                    ContactDetail(kind: .linkedin, value: "/in/priyanair", tier: .publicTier),
                    ContactDetail(kind: .x, value: "@priya_arc", tier: .publicTier)
                ],
                credentials: ["MEng, Imperial College London"],
                skills: ["Seed", "Deep tech", "Board work"],
                visibility: .privateMode,
                stories: [
                    StoryUpdate(
                        imageName: "rooftop_gathering_dusk",
                        caption: "Portfolio dinner, good year.",
                        postedAt: Date().addingTimeInterval(-11 * 3600)
                    )
                ]
            ),
            BusinessCard(
                name: "Tom Reilly",
                title: "Chief Technology Officer",
                company: "Sparkline",
                industry: "Data",
                tagline: "Make the hard numbers obvious.",
                location: "Dublin, IE",
                photoName: "man_cto_portrait",
                palette: .graphite,
                monogram: "TR",
                details: [
                    ContactDetail(kind: .mobile, value: "+353 85 555 0177", tier: .trusted),
                    ContactDetail(kind: .email, value: "tom@sparkline.io", tier: .connected),
                    ContactDetail(kind: .linkedin, value: "/in/tomreilly", tier: .publicTier)
                ],
                credentials: ["PhD Computer Science, Trinity College Dublin"],
                skills: ["Analytics", "Infrastructure", "ML"],
                visibility: .live
            )
        ]
    }

    static func makeRooms(attendeeIDs: [UUID]) -> [Room] {
        [
            Room(
                name: "TechWeek Mixer",
                venue: "Shoreditch",
                city: "London, UK",
                blurb: "Founders, builders and operators in tech. Good conversations.",
                imageName: "warehouse_networking_event",
                distanceMiles: 0.2,
                liveCount: 38,
                access: .openDoor,
                membership: .joined,
                attendeeIDs: attendeeIDs
            ),
            Room(
                name: "Founders Breakfast",
                venue: "Clerkenwell",
                city: "London, UK",
                blurb: "Early-stage founders, investors and friends. Coffee on us.",
                imageName: "founders_breakfast_cafe",
                distanceMiles: 1.1,
                liveCount: 12,
                access: .request
            ),
            Room(
                name: "Design Guild Meetup",
                venue: "King's Cross",
                city: "London, UK",
                blurb: "Designers, product people and creative minds. All are welcome.",
                imageName: "design_studio_meetup",
                distanceMiles: 2.4,
                liveCount: 21,
                access: .openDoor
            ),
            Room(
                name: "Creators Club",
                venue: "Peckham Rooftop",
                city: "London, UK",
                blurb: "Creators, writers and independent studios trading notes.",
                imageName: "rooftop_gathering_dusk",
                distanceMiles: 3.7,
                liveCount: 28,
                access: .ticketed,
                hostID: attendeeIDs.count > 1 ? attendeeIDs[1] : nil,
                ticketPrice: 15
            )
        ]
    }
}
