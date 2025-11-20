read -p "This will delete all Xcode DerivedData. Are you sure? (y/N) " answer
if [[ $answer =~ ^[Yy]$ ]]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    echo "DerivedData cleaned!"
else
    echo "Cancelled."
fi