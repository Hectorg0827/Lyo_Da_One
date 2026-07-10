import re

pbx = 'Lyo.xcodeproj/project.pbxproj'
text = open(pbx).read()

file_ref = '16D41507EC064F7AABF41E1B'

# Remove from wrong Community group
text = text.replace('\t\t\t\t16D41507EC064F7AABF41E1B /* StudyPlanView.swift */,\n', '')

# Add to correct Components group (the one with MagicalBackgroundView)
marker = 'C2113F8FD30144CDBCD55555 /* MagicalBackgroundView.swift */,'
text = text.replace(marker, marker + '\n\t\t\t\t' + file_ref + ' /* StudyPlanView.swift */,')

open(pbx, 'w').write(text)
print("Moved StudyPlanView to correct Components group")
