"""Hand-picked and time-order reading plans (drafts for pastoral review).

Readings are whole chapters ("MAT 5", "1KI 12-22"), the unit the app's plans
use. Two kinds of plan:

- "readings": the passages of each day, listed by hand.
- "sequence": an ordered list of chapter ranges that covers its books exactly
  once; build_plans.py splits it into days balanced by verse count.

Time order is approximate and at chapter level: Job sits with the
patriarchs, the Psalms with David, Proverbs, Ecclesiastes and Song of Songs
with Solomon, the prophets with the kings they served, and the letters
with Acts. The Gospels follow the rough order of events in Jesus' life.
Reviewers can reorder freely; the pipeline tests check that every
sequence still reads each chapter of its books once.
"""

# The four Gospels, each chapter once, in the rough order of events.
LIFE_OF_JESUS = [
    "JHN 1", "LUK 1", "MAT 1", "LUK 2", "MAT 2", "MRK 1", "MAT 3", "MAT 4", "LUK 3", "LUK 4",
    "JHN 2", "JHN 3", "JHN 4", "MRK 2", "LUK 5", "JHN 5", "MRK 3", "MAT 5", "MAT 6", "MAT 7",
    "LUK 6", "MAT 8", "LUK 7", "MAT 9", "MAT 10", "MAT 11", "MAT 12", "LUK 8", "MRK 4", "MAT 13",
    "MRK 5", "MRK 6", "MAT 14", "LUK 9", "JHN 6", "MAT 15", "MRK 7", "MAT 16", "MRK 8", "MAT 17",
    "MRK 9", "MAT 18", "JHN 7", "JHN 8", "LUK 10", "JHN 9", "JHN 10", "LUK 11", "LUK 12", "LUK 13",
    "LUK 14", "LUK 15", "LUK 16", "LUK 17", "JHN 11", "MAT 19", "MRK 10", "LUK 18", "MAT 20", "LUK 19",
    "MAT 21", "MRK 11", "JHN 12", "MAT 22", "MRK 12", "LUK 20", "MAT 23", "MAT 24", "MRK 13", "LUK 21",
    "MAT 25", "MAT 26", "MRK 14", "LUK 22", "JHN 13", "JHN 14", "JHN 15", "JHN 16", "JHN 17", "JHN 18",
    "MAT 27", "MRK 15", "LUK 23", "JHN 19", "MAT 28", "MRK 16", "LUK 24", "JHN 20", "JHN 21",
]

# The whole Bible in the rough order events happened.
CHRONOLOGICAL = [
    # Beginnings and the patriarchs (Job is usually placed in this era).
    "GEN 1-11", "JOB 1-42", "GEN 12-50",
    # Exodus and the wilderness.
    "EXO 1-40", "LEV 1-27", "NUM 1-36", "DEU 1-34",
    # The land and the judges.
    "JOS 1-24", "JDG 1-21", "RUT 1-4",
    # Saul and David, with the Psalms.
    "1SA 1-31", "2SA 1-24", "1CH 1-29", "PSA 1-150",
    # Solomon and his writings.
    "1KI 1-11", "2CH 1-9", "PRO 1-31", "ECC 1-12", "SNG 1-8",
    # The divided kingdom and the early prophets.
    "1KI 12-22", "2CH 10-20", "2KI 1-14", "JOL 1-3", "JON 1-4", "AMO 1-9", "HOS 1-14",
    "2KI 15-17", "2CH 21-28", "ISA 1-39", "MIC 1-7",
    # Hezekiah to Josiah.
    "2KI 18-20", "2CH 29-32", "ISA 40-66", "2KI 21-23", "2CH 33-35", "NAM 1-3", "ZEP 1-3", "HAB 1-3",
    # The fall of Jerusalem and the exile.
    "JER 1-52", "LAM 1-5", "2KI 24-25", "2CH 36", "OBA 1", "EZK 1-48", "DAN 1-12",
    # The return.
    "EZR 1-6", "HAG 1-2", "ZEC 1-14", "EST 1-10", "EZR 7-10", "NEH 1-13", "MAL 1-4",
    # Jesus.
    *LIFE_OF_JESUS,
    # The church, with each letter near the events of Acts it belongs to.
    "ACT 1-12", "JAS 1-5", "ACT 13-14", "GAL 1-6", "ACT 15-18", "1TH 1-5", "2TH 1-3", "ACT 19",
    "1CO 1-16", "2CO 1-13", "ROM 1-16", "ACT 20-28", "EPH 1-6", "PHP 1-4", "COL 1-4", "PHM 1",
    "1TI 1-6", "TIT 1-3", "1PE 1-5", "HEB 1-13", "2TI 1-4", "2PE 1-3", "JUD 1", "1JN 1-5", "2JN 1",
    "3JN 1", "REV 1-22",
]

CURATED_PLANS = [
    {
        "id": "sermon-parables-7",
        "name": {"am": "የተራራው ስብከትና ምሳሌዎች", "en": "The Sermon on the Mount and the parables"},
        "description": {
            "am": "የኢየሱስን ትምህርት በማቴዎስ 5–7 እና የታወቁ ምሳሌዎቹን በአንድ ሳምንት ያንብቡ።",
            "en": "Jesus' teaching in Matthew 5–7 and his best-known parables, in a week.",
        },
        "focus": ["gospels", "nt"],
        "readings": [
            ["MAT 5"],  # the Beatitudes, salt and light
            ["MAT 6"],  # the Lord's Prayer
            ["MAT 7"],  # the wise and foolish builders
            ["MAT 13"],  # the sower, the mustard seed, the hidden treasure
            ["LUK 10"],  # the Good Samaritan
            ["LUK 15"],  # the lost sheep, coin and son
            ["MAT 25"],  # the ten virgins, the talents, the sheep and the goats
        ],
    },
    {
        "id": "psalms-comfort-7",
        "name": {"am": "የመጽናናት መዝሙሮች", "en": "Psalms of comfort"},
        "description": {
            "am": "ለአስቸጋሪ ቀናት የሚሆኑ መዝሙሮች፤ 23፣ 27፣ 46፣ 91፣ 121፣ 139 እና ሌሎችም፤ በአንድ ሳምንት።",
            "en": "Psalms for hard days: 23, 27, 46, 91, 121, 139 and more, in a week.",
        },
        "focus": ["wisdom"],
        "readings": [
            ["PSA 23", "PSA 121"],  # the shepherd; help from the LORD
            ["PSA 27"],  # the LORD is my light
            ["PSA 34"],  # near to the brokenhearted
            ["PSA 46", "PSA 62"],  # refuge and strength; rest in God alone
            ["PSA 91"],  # under his wings
            ["PSA 103"],  # bless the LORD, who heals
            ["PSA 139"],  # known and held
        ],
    },
    {
        "id": "life-of-jesus-89",
        "name": {"am": "የኢየሱስ ሕይወት በጊዜ ቅደም ተከተል", "en": "The life of Jesus in time order"},
        "description": {
            "am": "አራቱ ወንጌላት በየምዕራፉ፣ ክንውኖቹ በተፈጸሙበት ቅደም ተከተል በግምት፤ በቀን አንድ ምዕራፍ።",
            "en": "The four Gospels, a chapter a day, in the rough order of events.",
        },
        "focus": ["gospels", "nt"],
        "sequence": LIFE_OF_JESUS,
        "days": 89,
    },
    {
        "id": "bible-chronological-365",
        "name": {"am": "መጽሐፍ ቅዱስ በጊዜ ቅደም ተከተል", "en": "The Bible in time order"},
        "description": {
            "am": "ሙሉውን መጽሐፍ ቅዱስ በአንድ ዓመት፣ ክንውኖቹ በተፈጸሙበት ቅደም ተከተል በግምት፤ ነቢያት ከነገሥታቱ ጋር፣ መልእክቶች ከሐዋርያት ሥራ ጋር።",
            "en": "The whole Bible in a year, in the rough order events happened: prophets with the kings, letters with Acts.",
        },
        "focus": ["all"],
        "sequence": CHRONOLOGICAL,
        "days": 365,
    },
]
